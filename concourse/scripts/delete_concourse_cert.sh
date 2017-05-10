#!/bin/sh

set -eu

concourse_fqdn="${CONCOURSE_HOSTNAME}.${SYSTEM_DNS_ZONE_NAME}"

arn=$(aws acm list-certificates --query "CertificateSummaryList[?DomainName==\`${concourse_fqdn}\`].CertificateArn" --output text)

if [ -z "${arn}" ] || [ "${arn}" = "None" ]; then
  echo "No cert found for ${concourse_fqdn}. Skipping..."
  exit 0
fi

echo "Deleting cert for ${concourse_fqdn} - arn: ${arn}"
aws acm delete-certificate --certificate-arn "${arn}"
