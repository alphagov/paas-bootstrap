#!/bin/bash
set -euo pipefail

if [[ -n "${PAAS_IN_BOSH_CLI_SUBSHELL:-}" ]]; then
  echo "You're already in a BOSH CLI subshell"
  exit 1
fi

bosh_config_dir="$(mktemp -d)"
if [[ ! -d "${bosh_config_dir}" ]]; then
  echo "Failed to create temporary directory: ${bosh_config_dir}"
  exit 1
fi

tunnel_mux=$(mktemp --dry-run /tmp/bosh-ssh-tunnel.mux.XXXXXXXX)

socks_port=25555
while nc -z localhost $socks_port >/dev/null 2>&1; do
  socks_port=$(( socks_port + 1 ))
done

function cleanup() {
  echo 'Closing SSH tunnel'
  ssh -S "$tunnel_mux" -O exit a-destination &>/dev/null || true
  # Avoid keeping sensitive tokens in bosh config when we don't need them.
  # This will mean we have to sign in to bosh every time we run this script.
  echo 'Cleaning up BOSH config'
  rm -f "${tunnel_mux}"
  rm -rf "${bosh_config_dir}"
}

trap cleanup EXIT

echo 'Getting BOSH settings'
BOSH_CA_CERT="$(aws s3 cp "s3://gds-paas-${DEPLOY_ENV}-state/bosh-CA.crt" -)"

echo 'Opening SSH tunnel'
ssh -qfNC -4 -D $socks_port \
  -o Hostname="bosh-external.${SYSTEM_DNS_ZONE_NAME}" \
  -o ExitOnForwardFailure=yes \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -o ServerAliveInterval=30 \
  -M \
  -S "${tunnel_mux}" \
  paas_bosh_ssh

export BOSH_CA_CERT
export BOSH_ALL_PROXY="socks5://localhost:$socks_port"
export BOSH_ENVIRONMENT="bosh.${SYSTEM_DNS_ZONE_NAME}"
export BOSH_DEPLOYMENT="${DEPLOY_ENV}"
export BOSH_CONFIG="${bosh_config_dir}/config"

export PAAS_IN_BOSH_CLI_SUBSHELL=true

echo "
  ,--.                 .--.
  |  |-.  ,---.  ,---. |  '---.
  | .-. '| .-. |(  .-' |  .-.  |
  | '-' |' '-' '.-'  ')|  | |  |
   '---'  '---' '----' '--' '--'
  1. Run 'bosh login'
  2. Skip entering a username and password
  3. Enter the passcode from https://bosh-uaa-external.${SYSTEM_DNS_ZONE_NAME}/passcode
"
if [[ "${SHELL}" == *bash ]]; then
  PS1="BOSH ($DEPLOY_ENV) $ " ${SHELL} --login --norc --noprofile
else
  ${SHELL}
fi
