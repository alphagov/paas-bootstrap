#!/bin/sh

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

# shellcheck disable=SC1090
. "${SCRIPT_DIR}/common_cert_management.sh"

arn=$(get_certificate_arn "$ACM_DOMAIN_FQDN")

if [ -z "${arn}" ] || [ "${arn}" = "None" ]; then
  echo "Requesting certificate for ${ACM_DOMAIN_FQDN} in ${AWS_DEFAULT_REGION}"
  if [ "${ACM_DOMAIN_FQDN#*\*\.}" != "${ACM_DOMAIN_FQDN}" ]; then
    # If it's a wildcard domain we automatically add an alternative name without the wildcard
    arn=$(aws acm request-certificate --domain-name "${ACM_DOMAIN_FQDN}" --subject-alternative-names "${ACM_DOMAIN_FQDN#*\*\.}" --validation-method "DNS" --output text)
  else
    arn=$(aws acm request-certificate --domain-name "${ACM_DOMAIN_FQDN}" --validation-method "DNS" --output text)
  fi
fi

cert_status=$(aws acm describe-certificate --certificate-arn "${arn}" --query 'Certificate.Status' --output text)
if [ "${cert_status}" = "ISSUED" ]; then
  echo "Certificate already issued for ${ACM_DOMAIN_FQDN} in ${AWS_DEFAULT_REGION}. No change required..."
fi

# The validation records are not returned for a couple of seconds from the API after creation
echo "Getting DNS validation records"
for _ in $(seq 20); do
  sleep 3

  dns_validation_record='null'
  dns_validation_value='null'
  cert_info=
  get_dns_validation_record "$arn"
  if [ "null" != "${dns_validation_record}" ] && [ "null" != "${dns_validation_value}" ]; then
    break
  fi
done

if [ "null" = "${dns_validation_record}" ] || [ "null" = "${dns_validation_value}" ]; then
  echo "DNS validation records are not found in the AWS API response: ${cert_info}"
  echo
  echo "Please run the script again"
  exit 1
fi

current_dns_validation_value="$(
  get_route53_resource_record_value \
    "${ACM_DOMAIN_ZONE_ID}" "${dns_validation_record}"
)"

if [ "${current_dns_validation_value}" = "${dns_validation_value}" ]; then
  echo "DNS validation record is valid, exitting..."
  exit 0
fi

echo "Upserting DNS validation record: ${dns_validation_record} for ${AWS_DEFAULT_REGION}"

aws route53 change-resource-record-sets --hosted-zone-id "${ACM_DOMAIN_ZONE_ID}" --change-batch "$(get_route53_change_batch UPSERT)" > /dev/null

cat <<EOT

The certificate for ${ACM_DOMAIN_FQDN} has been requested. To verify this,
a new DNS record has been created on your domain and Amazon will
automatically validate this request. Once that is done, the certificate
can be used.

This script will now poll for up to 10 mins waiting for this to happen.
EOT

for _ in $(seq 40); do
  sleep 15
  printf "."
  cert_status=$(aws acm describe-certificate --certificate-arn "${arn}" --query 'Certificate.Status' --output text)
  if [ "${cert_status}" = "ISSUED" ]; then
    echo
    echo "Cert issued successfully in ${AWS_DEFAULT_REGION}."

    exit 0
  fi
done
echo

echo "Certificate still not approved. Giving up waiting."
exit 1
