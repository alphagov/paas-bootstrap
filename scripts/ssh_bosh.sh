#!/bin/bash
set -euo pipefail

BOSH_KEY=/tmp/bosh_id_rsa.$RANDOM
BOSH_IP=$(aws ec2 describe-instances \
    --filters "Name=key-name,Values=${DEPLOY_ENV}_bosh_ssh_key_pair" \
    --query 'Reservations[].Instances[].PublicIpAddress' --output text)

trap 'rm -f ${BOSH_KEY}' EXIT

aws s3 cp "s3://gds-paas-${DEPLOY_ENV}-state/bosh_id_rsa" ${BOSH_KEY} && chmod 400 ${BOSH_KEY}

aws s3 cp "s3://gds-paas-${DEPLOY_ENV}-state/bosh-secrets.yml" - | \
  ruby -ryaml -e 'puts "Sudo password is " + YAML.load(STDIN)["secrets"]["vcap_password_orig"]'
echo

# shellcheck disable=SC2029
ssh \
    -i "$BOSH_KEY" \
    -o ServerAliveInterval=60 \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    "vcap@$BOSH_IP"
