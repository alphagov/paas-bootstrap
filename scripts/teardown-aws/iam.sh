#!/bin/bash

source scripts/teardown-aws/logging-and-sanitisation.sh

# Function to delete IAM user after removing associated objects
delete_iam_user() {
  user_name=$1

  echo "Processing IAM User: $user_name"

  # Check if the IAM user has any access keys and delete them first
  access_keys=$(aws iam list-access-keys --user-name "$user_name" --query "AccessKeyMetadata[].AccessKeyId" --output text)
  if [ -n "$access_keys" ]; then
    echo "Deleting access keys for user $user_name..."
    for access_key in $access_keys; do
      aws iam delete-access-key --access-key-id "$access_key" --user-name "$user_name"
      if [ $? -ne 0 ]; then
        echo "Failed to delete access key $access_key for user $user_name"
      fi
    done
  fi

  # Check if the IAM user is in any groups and remove them
  user_groups=$(aws iam list-groups-for-user --user-name "$user_name" --query "Groups[].GroupName" --output text)
  if [ -n "$user_groups" ]; then
    echo "Removing user $user_name from groups..."
    for group in $user_groups; do
      aws iam remove-user-from-group --group-name "$group" --user-name "$user_name"
      if [ $? -ne 0 ]; then
        echo "Failed to remove user $user_name from group $group"
      fi
    done
  fi

  # Check if the IAM user has any inline policies and delete them
  user_inline_policies=$(aws iam list-user-policies --user-name "$user_name" --query "PolicyNames[]" --output text)
  if [ -n "$user_inline_policies" ]; then
    echo "Deleting inline policies for user $user_name..."
    for policy in $user_inline_policies; do
      aws iam delete-user-policy --user-name "$user_name" --policy-name "$policy"
      if [ $? -ne 0 ]; then
        echo "Failed to delete inline policy $policy for user $user_name"
      fi
    done
  fi

  # Check if the IAM user has any managed policies attached and detach them
  user_policies=$(aws iam list-attached-user-policies --user-name "$user_name" --query "AttachedPolicies[].PolicyArn" --output text)
  if [ -n "$user_policies" ]; then
    echo "Detaching policies from user $user_name..."
    for policy in $user_policies; do
      aws iam detach-user-policy --user-name "$user_name" --policy-arn "$policy"
      if [ $? -ne 0 ]; then
        echo "Failed to detach policy $policy from user $user_name"
      fi
    done
  fi

  # Now attempt to delete the IAM user after ensuring all resources are cleared
  echo "Attempting to delete IAM user: $user_name"
  aws iam delete-user --user-name "$user_name"

  # Check for success or failure
  if [ $? -ne 0 ]; then
    echo "[ERROR] Failed to delete IAM User: $user_name. Check for active resources or session."
  else
    echo "Successfully deleted IAM user: $user_name"
  fi
}

# Delete IAM Users
echo "Deleting IAM Users..."
aws iam list-users --query "Users[?contains(UserName, '${DEPLOY_ENV}')].UserName" --output text | \
sanitize_and_execute delete_iam_user