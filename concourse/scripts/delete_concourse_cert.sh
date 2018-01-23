#!/bin/sh

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

# shellcheck disable=SC1090
. "${SCRIPT_DIR}/common_cert_management.sh"

concourse_fqdn="${CONCOURSE_HOSTNAME}.${SYSTEM_DNS_ZONE_NAME}"

arn=$(get_certificate_arn "$concourse_fqdn")

if [ -z "${arn}" ] || [ "${arn}" = "None" ]; then
  echo "No cert found for ${concourse_fqdn}. Skipping..."
  exit 0
fi

echo "Deleting DNS validation record for ${concourse_fqdn} - ARN: ${arn}"
dns_validation_record='null'
dns_validation_value='null'
cert_info=
get_dns_validation_record "$arn"

if [ "null" = "${dns_validation_record}" ] || [ "null" = "${dns_validation_value}" ]; then
  echo "DNS validation records are not found in the AWS API response: ${cert_info}"
  exit 1
fi

aws route53 change-resource-record-sets --hosted-zone-id "${SYSTEM_DNS_ZONE_ID}" --change-batch "$(get_route53_change_batch DELETE)" > /dev/null

echo "Deleting cert for ${concourse_fqdn} - ARN: ${arn}"
aws acm delete-certificate --certificate-arn "${arn}"
