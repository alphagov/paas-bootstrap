#!/bin/bash
set -euo pipefail

SSH_PATH=${SSH_PATH:-"/Users/${USER}/.ssh/id_rsa"}

BOSH_KEY=/tmp/id_rsa.$RANDOM
BOSH_IP=$(aws ec2 describe-instances \
    --filters "Name=tag:deploy_env,Values=${DEPLOY_ENV}" 'Name=tag:instance_group,Values=bosh' \
    --query 'Reservations[].Instances[].PublicIpAddress' --output text)

trap 'rm -f ${BOSH_KEY}' EXIT

aws s3 cp "s3://gds-paas-${DEPLOY_ENV}-state/id_rsa" ${BOSH_KEY} && chmod 400 ${BOSH_KEY}

aws s3 cp "s3://gds-paas-${DEPLOY_ENV}-state/bosh-secrets.yml" - | \
  ruby -ryaml -e 'puts "Sudo password is " + YAML.load(STDIN)["secrets"]["vcap_password_orig"]'
echo

# shellcheck disable=SC2029
ssh \
    -i "$SSH_PATH" \
    -o IdentitiesOnly=yes \
    -o ServerAliveInterval=60 \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    "$USER"@"$BOSH_IP"
