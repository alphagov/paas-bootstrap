#!/bin/bash

source scripts/teardown-aws/logging-and-sanitisation.sh

# Set the hosted zone name and prefix for records
HOSTED_ZONE_NAME="dev.cloudpipeline.digital"

# Get the Hosted Zone ID for the specified zone
HOSTED_ZONE_ID=$(aws route53 list-hosted-zones-by-name --dns-name "$HOSTED_ZONE_NAME" --query "HostedZones[?Name == '$HOSTED_ZONE_NAME.'].Id" --output text)

if [ -z "$HOSTED_ZONE_ID" ]; then
  echo "Hosted Zone $HOSTED_ZONE_NAME not found."
else
  echo "Found Hosted Zone: $HOSTED_ZONE_NAME with ID: $HOSTED_ZONE_ID"

  echo "Deleting Route 53 Records containing '${DEPLOY_ENV}'..."
  aws route53 list-resource-record-sets --hosted-zone-id "$HOSTED_ZONE_ID" --query "ResourceRecordSets[?contains(Name, '${DEPLOY_ENV}')]" --output json | \
  jq -c '.[]' | while read -r record; do
    NAME=$(echo "$record" | jq -r '.Name')
    TYPE=$(echo "$record" | jq -r '.Type')
    if [ -n "$NAME" ] && [ -n "$TYPE" ]; then
      echo "Deleting record: $NAME ($TYPE)"
      aws route53 change-resource-record-sets --hosted-zone-id "$HOSTED_ZONE_ID" --change-batch '{
        "Changes": [
          {
            "Action": "DELETE",
            "ResourceRecordSet": '"$record"'
          }
        ]
      }'
    else
      echo "Skipping invalid Route 53 record: $record"
    fi
  done
fi