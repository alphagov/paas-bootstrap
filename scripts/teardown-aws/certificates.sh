#!/bin/bash

source scripts/teardown-aws/logging-and-sanitisation.sh

# Find certificates with 'dev02' in the domain name
CERT_ARN_LIST=$(aws acm list-certificates --region "$AWS_REGION" --query "CertificateSummaryList[?contains(DomainName, '${DEPLOY_ENV}')].CertificateArn" --output text)

if [[ -z "$CERT_ARN_LIST" ]]; then
  echo "No certificates found with '${DEPLOY_ENV}' in the domain name."
  exit 0
fi

echo "Found certificates:"
echo "$CERT_ARN_LIST"

# Iterate and delete each certificate
for CERT_ARN in $CERT_ARN_LIST; do
  echo "Deleting certificate: $CERT_ARN"
  aws acm delete-certificate --certificate-arn "$CERT_ARN" --region "$AWS_REGION"

  if [[ $? -eq 0 ]]; then
    echo "Successfully deleted $CERT_ARN"
  else
    echo "Failed to delete $CERT_ARN"
  fi
done

echo "Script completed."