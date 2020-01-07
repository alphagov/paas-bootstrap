#!/bin/bash

set -euo pipefail

case ${1:-} in
  concourse)
    env > /tmp/debug.txt
    aws ec2 describe-instances \
      --filters "Name=tag:deploy_env,Values=${DEPLOY_ENV}" 'Name=tag:instance_group,Values=concourse' \
      --query 'Reservations[].Instances[].PublicIpAddress' --output text
    ;;
  bootstrap)
    aws ec2 describe-instances \
      --filters 'Name=tag:Name,Values=*concourse' "Name=key-name,Values=${VAGRANT_SSH_KEY_NAME}" \
      --query 'Reservations[].Instances[].PublicIpAddress' --output text
    ;;
  *)
    usage "Unknown action '$1'"
    exit 1
    ;;
esac
