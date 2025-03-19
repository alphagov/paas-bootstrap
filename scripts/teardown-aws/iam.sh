#!/bin/bash

source scripts/teardown-aws/logging-and-sanitisation.sh

# Function to delete IAM user after removing associated objects
delete_iam_user() {
  user_name=$1

  echo "Processing IAM User: $user_name"

  # Delete access keys
  access_keys=$(aws iam list-access-keys --user-name "$user_name" --query "AccessKeyMetadata[].AccessKeyId" --output text)
  if [ -n "$access_keys" ]; then
    echo "Deleting access keys for user $user_name..."
    for access_key in $access_keys; do
      if ! aws iam delete-access-key --access-key-id "$access_key" --user-name "$user_name"; then
        echo "[ERROR] Failed to delete access key $access_key for user $user_name"
      else
        echo "Deleted access key $access_key for user $user_name"
      fi
    done
  fi

  # Remove from groups
  user_groups=$(aws iam list-groups-for-user --user-name "$user_name" --query "Groups[].GroupName" --output text)
  if [ -n "$user_groups" ]; then
    echo "Removing user $user_name from groups..."
    for group in $user_groups; do
      if ! aws iam remove-user-from-group --group-name "$group" --user-name "$user_name"; then
        echo "[ERROR] Failed to remove user $user_name from group $group"
      else
        echo "Removed user $user_name from group $group"
      fi
    done
  fi

  # Delete inline policies
  user_inline_policies=$(aws iam list-user-policies --user-name "$user_name" --query "PolicyNames[]" --output text)
  if [ -n "$user_inline_policies" ]; then
    echo "Deleting inline policies for user $user_name..."
    for policy in $user_inline_policies; do
      if ! aws iam delete-user-policy --user-name "$user_name" --policy-name "$policy"; then
        echo "[ERROR] Failed to delete inline policy $policy for user $user_name"
      else
        echo "Deleted inline policy $policy for user $user_name"
      fi
    done
  fi

  # Detach managed policies
  user_policies=$(aws iam list-attached-user-policies --user-name "$user_name" --query "AttachedPolicies[].PolicyArn" --output text)
  if [ -n "$user_policies" ]; then
    echo "Detaching policies from user $user_name..."
    for policy in $user_policies; do
      if ! aws iam detach-user-policy --user-name "$user_name" --policy-arn "$policy"; then
        echo "[ERROR] Failed to detach policy $policy from user $user_name"
      else
        echo "Detached policy $policy from user $user_name"
      fi
    done
  fi

  # Delete user
  echo "Attempting to delete IAM user: $user_name"
  if ! aws iam delete-user --user-name "$user_name"; then
    echo "[ERROR] Failed to delete IAM User: $user_name. Check for active resources or session."
  else
    echo "Successfully deleted IAM user: $user_name"
  fi
}

# Delete IAM Users
echo "Fetching list of IAM Users..."
aws iam list-users --query "Users[?contains(UserName, '${DEPLOY_ENV}')].UserName" --output text | tr '\t' '\n' | \
while IFS= read -r user_name; do
  if [[ -n "$user_name" ]]; then
    delete_iam_user "$user_name"
  fi
done
