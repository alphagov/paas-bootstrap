#!/bin/sh

set -euo pipefail

concourse_fqdn="${CONCOURSE_HOSTNAME}.${SYSTEM_DNS_ZONE_NAME}"

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

arn=$(aws acm list-certificates --query "CertificateSummaryList[?DomainName==\`${concourse_fqdn}\`].CertificateArn" --output text)

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

  cert_info=$(aws acm describe-certificate --certificate-arn "${arn}" --query 'Certificate')
  dns_validation_record=$(echo "${cert_info}" | jq -r '.DomainValidationOptions[0].ResourceRecord.Name')
  dns_validation_value=$(echo "${cert_info}" | jq -r '.DomainValidationOptions[0].ResourceRecord.Value')

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

zone_id=$(aws route53 list-hosted-zones-by-name --dns-name dev.cloudpipeline.digital --query 'HostedZones[0].Id' --output text | cut -d '/' -f 3)

echo "Upserting DNS validation record: ${dns_validation_record}"

aws route53 change-resource-record-sets --hosted-zone-id "${zone_id}" --change-batch "$(get_route53_change_batch UPSERT)" > /dev/null

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

    echo "Deleting DNS validation record."
    aws route53 change-resource-record-sets --hosted-zone-id "${zone_id}" --change-batch "$(get_route53_change_batch DELETE)" > /dev/null

    exit 0
  fi
done
echo

echo "Certificate still not approved. Giving up waiting."
exit 1
