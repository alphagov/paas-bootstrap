#!/bin/bash
set -euo pipefail

tunnel_mux='/tmp/bosh-ssh-tunnel.mux'

function cleanup () {
  echo 'Closing SSH tunnel'
  ssh -S "$tunnel_mux" -O exit a-destination &>/dev/null || true

  # Avoid keeping sensitive tokens in bosh config when we don't need them.
  # This will mean we have to sign in to bosh every time we run this script.
  rm -f ~/.bosh/config
}

trap cleanup EXIT

echo 'Getting BOSH settings'

BOSH_CA_CERT="$(aws s3 cp "s3://gds-paas-${DEPLOY_ENV}-state/bosh-CA.crt" -)"
BOSH_IP=$(aws ec2 describe-instances \
    --filters "Name=tag:deploy_env,Values=${DEPLOY_ENV}" 'Name=tag:instance_group,Values=bosh' \
    --query 'Reservations[].Instances[].PublicIpAddress' --output text)

echo 'Opening SSH tunnel'
ssh -qfNC -4 -D 25555 \
  -o ExitOnForwardFailure=yes \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -o ServerAliveInterval=30 \
  -M \
  -S "$tunnel_mux" \
  "$BOSH_IP"

export BOSH_CA_CERT
export BOSH_ALL_PROXY="socks5://localhost:25555"
export BOSH_ENVIRONMENT="bosh.${SYSTEM_DNS_ZONE_NAME}"
export BOSH_DEPLOYMENT="${DEPLOY_ENV}"

echo "
  ,--.                 .--.
  |  |-.  ,---.  ,---. |  '---.
  | .-. '| .-. |(  .-' |  .-.  |
  | '-' |' '-' '.-'  ')|  | |  |
   '---'  '---' '----' '--' '--'
  1. Run 'bosh login'
  2. Skip entering a username and password
  3. Enter the passcode from bosh-external.${SYSTEM_DNS_ZONE_NAME}
"

PS1="BOSH ($DEPLOY_ENV) $ " bash --login --norc --noprofile
