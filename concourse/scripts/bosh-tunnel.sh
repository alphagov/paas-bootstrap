#!/bin/sh

chmod 400 "${BOSH_GW_PRIVATE_KEY}"

# shellcheck disable=SC2029
ssh -fNC -4 -D 8888 \
  -o ExitOnForwardFailure=yes \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -o ServerAliveInterval=30 \
  -M -S /tmp/bosh-ssh-socket \
  -i "${BOSH_GW_PRIVATE_KEY}" \
  "${BOSH_GW_USER}@${BOSH_GW_HOST}"

export BOSH_ALL_PROXY="socks5://localhost:8888"

trap 'ssh -S /tmp/bosh-ssh-socket -O exit ${BOSH_GW_USER}@${BOSH_GW_HOST}' EXIT
