#!/bin/bash

set -eu

get_certificate_arn() {
  fqdn="$1"
  aws acm list-certificates \
    --query "CertificateSummaryList[?DomainName==\`${fqdn}\`].CertificateArn" \
    --output text
}

get_dns_validation_record() {
  arn="$1"
  cert_info=$(aws acm describe-certificate --certificate-arn "${arn}" --query 'Certificate')
  dns_validation_record=$(echo "${cert_info}" | jq -r '.DomainValidationOptions[0].ResourceRecord.Name')
  dns_validation_value=$(echo "${cert_info}" | jq -r '.DomainValidationOptions[0].ResourceRecord.Value')
}

get_route53_resource_record_value() {
  zone="$1"
  name="$2"
  aws route53 list-resource-record-sets \
    --hosted-zone-id "${zone}" \
    --query "ResourceRecordSets[?Name == '${name}'].ResourceRecords[0].Value" \
    --output text
}

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
