#!/bin/sh

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

# shellcheck disable=SC1090
. "${SCRIPT_DIR}/common_cert_management.sh"

concourse_fqdn="${CONCOURSE_HOSTNAME}.${SYSTEM_DNS_ZONE_NAME}"

arn=$(get_certificate_arn "$concourse_fqdn")

if [ -z "${arn}" ] || [ "${arn}" = "None" ]; then
  echo "Requesting certificate for ${concourse_fqdn}"
  arn=$(aws acm request-certificate --domain-name "${concourse_fqdn}" --validation-method "DNS" --output text)
fi

cert_status=$(aws acm describe-certificate --certificate-arn "${arn}" --query 'Certificate.Status' --output text)
if [ "${cert_status}" = "ISSUED" ]; then
  echo "Certificate already issued for ${concourse_fqdn}. Exiting..."
  exit 0
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

echo "Upserting DNS validation record: ${dns_validation_record}"

aws route53 change-resource-record-sets --hosted-zone-id "${SYSTEM_DNS_ZONE_ID}" --change-batch "$(get_route53_change_batch UPSERT)" > /dev/null

cat <<EOT

The certificate for ${concourse_fqdn} has been requested. To verify this,
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
    echo "Cert issued successfully."

    exit 0
  fi
done
echo

echo "Certificate still not approved. Giving up waiting."
exit 1
