#!/bin/bash

source scripts/teardown-aws/logging-and-sanitisation.sh

# Function to delete IAM user after removing associated objects
delete_iam_user() {
  user_name=$1

  echo "Processing IAM User: $user_name"

  # 1. Delete access keys
  access_keys=$(aws iam list-access-keys --user-name "$user_name" --query "AccessKeyMetadata[].AccessKeyId" --output text)
  if [ -n "$access_keys" ]; then
    echo "Deleting access keys for user $user_name..."
    for access_key in $access_keys; do
      aws iam delete-access-key --access-key-id "$access_key" --user-name "$user_name"
    done
  fi

  # 2. Remove user from groups
  user_groups=$(aws iam list-groups-for-user --user-name "$user_name" --query "Groups[].GroupName" --output text)
  if [ -n "$user_groups" ]; then
    echo "Removing user $user_name from groups..."
    for group in $user_groups; do
      aws iam remove-user-from-group --group-name "$group" --user-name "$user_name"
    done
  fi

  # 3. Delete inline policies
  user_inline_policies=$(aws iam list-user-policies --user-name "$user_name" --query "PolicyNames[]" --output text)
  if [ -n "$user_inline_policies" ]; then
    echo "Deleting inline policies for user $user_name..."
    for policy in $user_inline_policies; do
      aws iam delete-user-policy --user-name "$user_name" --policy-name "$policy"
    done
  fi

  # 4. Detach managed policies
  user_policies=$(aws iam list-attached-user-policies --user-name "$user_name" --query "AttachedPolicies[].PolicyArn" --output text)
  if [ -n "$user_policies" ]; then
    echo "Detaching policies from user $user_name..."
    for policy in $user_policies; do
      aws iam detach-user-policy --user-name "$user_name" --policy-arn "$policy"
    done
  fi

  # 5. Delete login profile (console password)
  aws iam delete-login-profile --user-name "$user_name" 2>/dev/null

  # 6. Deactivate and delete MFA devices
  mfa_devices=$(aws iam list-mfa-devices --user-name "$user_name" --query "MFADevices[].SerialNumber" --output text)
  if [ -n "$mfa_devices" ]; then
    echo "Removing MFA devices for user $user_name..."
    for mfa in $mfa_devices; do
      aws iam deactivate-mfa-device --user-name "$user_name" --serial-number "$mfa"
      aws iam delete-virtual-mfa-device --serial-number "$mfa"
    done
  fi

  # 7. Delete SSH public keys
  ssh_keys=$(aws iam list-ssh-public-keys --user-name "$user_name" --query "SSHPublicKeys[].SSHPublicKeyId" --output text)
  if [ -n "$ssh_keys" ]; then
    echo "Deleting SSH keys for user $user_name..."
    for ssh_key in $ssh_keys; do
      aws iam delete-ssh-public-key --user-name "$user_name" --ssh-public-key-id "$ssh_key"
    done
  fi

  # 8. Delete signing certificates
  signing_certs=$(aws iam list-signing-certificates --user-name "$user_name" --query "Certificates[].CertificateId" --output text)
  if [ -n "$signing_certs" ]; then
    echo "Deleting signing certificates for user $user_name..."
    for cert in $signing_certs; do
      aws iam delete-signing-certificate --user-name "$user_name" --certificate-id "$cert"
    done
  fi

  # 9. Delete service-specific credentials
  service_creds=$(aws iam list-service-specific-credentials --user-name "$user_name" --query "ServiceSpecificCredentials[].ServiceSpecificCredentialId" --output text)
  if [ -n "$service_creds" ]; then
    echo "Deleting service-specific credentials for user $user_name..."
    for cred in $service_creds; do
      aws iam delete-service-specific-credential --user-name "$user_name" --service-specific-credential-id "$cred"
    done
  fi

  # 10. Attempt to delete the IAM user
  echo "Attempting to delete IAM user: $user_name"
  
  # Check for success or failure
  if aws iam delete-user --user-name "$user_name"; then
    echo "[ERROR] Failed to delete IAM User: $user_name. Check for active resources or session."
  else
    echo "Successfully deleted IAM user: $user_name"
  fi
}

# Delete IAM Users
echo "Deleting IAM Users..."
iam_users=$(aws iam list-users --query "Users[?contains(UserName, '${DEPLOY_ENV}')].UserName" --output text)

for iam_user in $iam_users; do
  delete_iam_user "$iam_user"
done
