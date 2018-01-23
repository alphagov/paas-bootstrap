#!/bin/sh

set -eu

concourse_fqdn="${CONCOURSE_HOSTNAME}.${SYSTEM_DNS_ZONE_NAME}"

arn=$(aws acm list-certificates --query "CertificateSummaryList[?DomainName==\`${concourse_fqdn}\`].CertificateArn" --output text)

if [ -z "${arn}" ] || [ "${arn}" = "None" ]; then
  echo "No cert found for ${concourse_fqdn}. Skipping..."
  exit 0
fi

echo "Deleting DNS validation record for ${concourse_fqdn} - ARN: ${arn}"
cert_info=$(aws acm describe-certificate --certificate-arn "${arn}" --query 'Certificate')
dns_validation_record=$(echo "${cert_info}" | jq -r '.DomainValidationOptions[0].ResourceRecord.Name')
dns_validation_value=$(echo "${cert_info}" | jq -r '.DomainValidationOptions[0].ResourceRecord.Value')

if [ "null" = "${dns_validation_record}" ] || [ "null" = "${dns_validation_value}" ]; then
  echo "Could not find DNS validation records for ${concourse_fqdn} - ARN: ${arn}"
  exit 1
fi

get_route53_change_batch() {
  action=${1}
  cat <<EOF
{
  "Changes": [
    {
      "Action": "${action}",
      "ResourceRecordSet": {
        "Name": "${dns_validation_record}",
        "Type": "CNAME",
        "TTL": 300,
        "ResourceRecords": [
          {
            "Value": "${dns_validation_value}"
          }
        ]
      }
    }
  ]
}
EOF
}

aws route53 change-resource-record-sets --hosted-zone-id "${SYSTEM_DNS_ZONE_ID}" --change-batch "$(get_route53_change_batch DELETE)" > /dev/null

echo "Deleting cert for ${concourse_fqdn} - ARN: ${arn}"
aws acm delete-certificate --certificate-arn "${arn}"
