#!/bin/bash
set -euo pipefail

BOSH_IP=$(aws ec2 describe-instances \
    --filters "Name=tag:deploy_env,Values=${DEPLOY_ENV}" 'Name=tag:instance_group,Values=bosh' \
    --query 'Reservations[].Instances[].PublicIpAddress' --output text)

aws s3 cp "s3://gds-paas-${DEPLOY_ENV}-state/bosh-secrets.yml" - | \
  ruby -ryaml -e 'puts "Sudo password is " + YAML.load(STDIN)["secrets"]["vcap_password_orig"]'
echo

# shellcheck disable=SC2029
ssh \
    -o Hostname="${BOSH_IP}" \
    -o ServerAliveInterval=60 \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    paas_bosh_ssh
