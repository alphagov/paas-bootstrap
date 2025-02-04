#!/bin/bash

source scripts/teardown-aws/logging-and-sanitisation.sh

# Find log groups with '${DEPLOY_ENV}' in their names
LOG_GROUPS=$(aws logs describe-log-groups --query "logGroups[?contains(logGroupName, '${DEPLOY_ENV}')].logGroupName" --output text)

if [[ -z "$LOG_GROUPS" ]]; then
  echo "No log groups found with '${DEPLOY_ENV}' in their names."
  exit 0
fi

echo "Found log groups:"
echo "$LOG_GROUPS"

# Iterate and delete each log group
for LOG_GROUP in $LOG_GROUPS; do
  echo "Deleting log group: $LOG_GROUP"
  aws logs delete-log-group --log-group-name "$LOG_GROUP" --region "$AWS_REGION"
  
  if [[ $? -eq 0 ]]; then
    echo "Successfully deleted log group $LOG_GROUP"
  else
    echo "Failed to delete log group $LOG_GROUP"
  fi
done

echo "Script completed."
