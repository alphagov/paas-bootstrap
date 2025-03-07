#!/bin/bash

# Get a list of target groups containing the DEPLOY_ENV
TARGET_GROUP_ARNs=$(aws elbv2 describe-target-groups --query "TargetGroups[?contains(TargetGroupName, '${DEPLOY_ENV}')].TargetGroupArn" --output text)

if [ -z "$TARGET_GROUP_ARNs" ]; then
  echo "No target groups found containing '$DEPLOY_ENV'."
  exit 0
fi

echo "Found target groups containing '$DEPLOY_ENV':"
echo "$TARGET_GROUP_ARNs"

# Loop through each target group and delete it
for TG_ARN in $TARGET_GROUP_ARNs; do
  echo "Deleting target group: $TG_ARN..."
  aws elbv2 delete-target-group --target-group-arn "$TG_ARN"
  echo "Deleted $TG_ARN"
done

echo "All matching target groups deleted."