#!/bin/sh

set -eu

concourse_fqdn="${CONCOURSE_HOSTNAME}.${SYSTEM_DNS_ZONE_NAME}"

arn=$(aws acm list-certificates --query "CertificateSummaryList[?DomainName==\`${concourse_fqdn}\`].CertificateArn" --output text)

created_cert="false"
if [ -z "${arn}" ] || [ "${arn}" = "None" ]; then
  echo "Requesting certificate for ${concourse_fqdn}"
  arn=$(aws acm request-certificate --domain-name "${concourse_fqdn}" --output text)
  created_cert="true"
fi

cert_status=$(aws acm describe-certificate --certificate-arn "${arn}" --query 'Certificate.Status' --output text)
if [ "${cert_status}" = "ISSUED" ]; then
  echo "Certificate already issued for ${concourse_fqdn}. Exiting..."
  exit 0
fi

if [ "${created_cert}" = "false" ]; then
  echo "Resending validation email for ${concourse_fqdn} certificate"
  aws acm resend-validation-email --certificate-arn "${arn}" --domain "${concourse_fqdn}" --validation-domain "${SYSTEM_DNS_ZONE_NAME}"
fi

cat <<EOT
The certificate for ${concourse_fqdn} has been requested. To verify this,
emails will be sent to the paas-domain-admins containing a link to validate
this request. Once that is done, the certificate can be used.

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
