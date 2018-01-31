#!/bin/sh

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

# shellcheck disable=SC1090
. "${SCRIPT_DIR}/common_cert_management.sh"

arn=$(get_certificate_arn "$ACM_DOMAIN_FQDN")

if [ -z "${arn}" ] || [ "${arn}" = "None" ]; then
  echo "No cert found for ${ACM_DOMAIN_FQDN}. Skipping..."
  exit 0
fi

echo "Deleting DNS validation record for ${ACM_DOMAIN_FQDN} - ARN: ${arn}"
dns_validation_record='null'
dns_validation_value='null'
cert_info=
get_dns_validation_record "$arn"

if [ "null" = "${dns_validation_record}" ] || [ "null" = "${dns_validation_value}" ]; then
  echo "DNS validation records are not found in the AWS API response: ${cert_info}"
  exit 1
fi

aws route53 change-resource-record-sets --hosted-zone-id "${ACM_DOMAIN_ZONE_ID}" --change-batch "$(get_route53_change_batch DELETE)" > /dev/null

echo "Deleting cert for ${ACM_DOMAIN_FQDN} - ARN: ${arn}"
aws acm delete-certificate --certificate-arn "${arn}"
