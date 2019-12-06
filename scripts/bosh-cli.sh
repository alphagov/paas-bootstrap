#!/bin/bash
set -euo pipefail

dir="$(cd "$(dirname "$0")" && pwd)"
pac_url='http://localhost:9191/proxy.pac'
tunnel_mux='/tmp/bosh-ssh-tunnel.mux'
pacserverpid=''

if hash networksetup &> /dev/null; then
  old_auto_proxy_settings=$(networksetup -getautoproxyurl Wi-Fi)
  old_auto_proxy_url=$(awk '/^URL:/ { print $2 }' <<< "$old_auto_proxy_settings")
  old_auto_proxy_enabled=$(awk '/^Enabled:/ { print $2 }' <<< "$old_auto_proxy_settings")
fi
function cleanup () {
  if [ -n "$pacserverpid" ]; then
    echo 'Stopping PAC server'
    kill "$pacserverpid" &>/dev/null || true
  fi

  echo 'Closing SSH tunnel'
  ssh -S "$tunnel_mux" -O exit a-destination &>/dev/null || true

  # Avoid keeping sensitive tokens in bosh config when we don't need them.
  # This will mean we have to sign in to bosh every time we run this script.
  rm -f ~/.bosh/config

  if hash networksetup &> /dev/null; then
    echo 'Restoring network settings'
    networksetup -setautoproxyurl Wi-Fi "$old_auto_proxy_url" &>/dev/null || true
    if [ "$old_auto_proxy_enabled" == 'No' ]; then
      networksetup -setautoproxystate Wi-Fi off
    fi
  fi
}

trap cleanup EXIT

echo 'Starting PAC server'
ruby "$dir/../proxy/pacserver.rb" &>/dev/null &
pacserverpid="$!"

if hash networksetup &> /dev/null && [[ "$pac_url" != "$old_auto_proxy_url" || "$old_auto_proxy_enabled" == "No" ]]; then
  echo
  echo 'Your system network settings need to be changed to allow your browser to access UAA over our SSH tunnel.'
  echo 'Your current settings are: '
  echo "$old_auto_proxy_settings"
  echo
  while true; do
    read -r -p 'Would you like these to be changed? (y/n) ' yn
    case $yn in
        [Yy]* )
          echo
          networksetup -setautoproxyurl Wi-Fi "$pac_url" &>/dev/null
          networksetup -setautoproxystate Wi-Fi on
          networksetup -getautoproxyurl Wi-Fi
          echo
          break;;
        [Nn]* )
          echo
          echo 'Please configure your proxy settings to look at a PAC file or directly at the SOCKS5 proxy'
          echo "  PAC URL: $pac_url"
          echo '  SOCK5 URL: localhost:25555'
          echo
          break;;
        * ) echo 'Please answer yes or no.';;
    esac
  done
else
  echo
  echo 'Please configure your proxy settings to look at a PAC file or directly at the SOCKS5 proxy'
  echo "  PAC URL: $pac_url"
  echo '  SOCK5 URL: localhost:25555'
  echo
fi

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

  3. Enter a passcode from the URL given to you by BOSH

"

PS1="BOSH ($DEPLOY_ENV) $ " bash --login --norc --noprofile
