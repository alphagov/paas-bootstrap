#!/bin/bash

set -euo pipefail

SCRIPT=$0

SOCKET_DIR=~/.ssh
SOCKET_DEF=%r@%h:%p
SOCKET=$SOCKET_DIR/$SOCKET_DEF

usage() {
  if [ -n "${1:-}" ]; then
    echo "$@"
    echo
  fi
  cat <<EOF
Usage:

  $SCRIPT <action> [-- action_params]

SSH/SCP to concourse.

actions:
  ssh [command]     (default) SSH to concourse.
                    Optionally run the provided command

  scp <from> <to>   Copy 'from' local file to 'to' location on Concourse.

  tunnel <tunnel>   Configure a TCP ssh tunnel for the given port
                    Syntax: <local_port>:<remote_ip>:<remote_port>

                    Use 'tunnel stop' to stop the tunnel.

EOF
}

download_key() {
  key=/tmp/id_rsa.$RANDOM
  trap 'rm -f $key' EXIT

  eval "$(make "${MAKEFILE_ENV_TARGET}" showenv | grep CONCOURSE_IP=)"
  aws s3 cp "s3://gds-paas-${DEPLOY_ENV}-state/id_rsa" $key && chmod 400 $key
}

ssh_concourse() {
  echo
  aws s3 cp "s3://gds-paas-${DEPLOY_ENV}-state/bosh-secrets.yml" - | \
  ruby -ryaml -e 'puts "Sudo password is " + YAML.safe_load(STDIN, aliases: true)["secrets"]["vcap_password_orig"]'
  echo

  # shellcheck disable=SC2029
  ssh -t -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ServerAliveInterval=60 \
    "$USER"@"$CONCOURSE_IP" "$@"
}

scp_concourse() {
  # shellcheck disable=SC2029
  scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ServerAliveInterval=60 \
    "$1" "$USER"@"$CONCOURSE_IP":"$2"
}

create_tunnel() {
  TUNNEL=$1
  echo "Creating tunnel at socket $(print_socket) to ${TUNNEL}"
  ssh -fNTM -o ControlPath=${SOCKET} -o "ExitOnForwardFailure yes" \
    -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ServerAliveInterval=60 \
    -L "${TUNNEL}" "${USER}"@"${CONCOURSE_IP}"
}

stop_tunnel() {
  echo "Stopping tunnel at socket $(print_socket)"
  ssh -T -O "exit" -o ControlPath=${SOCKET} "${USER}"@"${CONCOURSE_IP}"
}

print_socket() {
  echo -n "$SOCKET_DIR/${USER}@${CONCOURSE_IP}"
}


case ${1:-} in
  ssh|"")
    shift || true
    download_key
    ssh_concourse "$@"
    ;;
  scp)
    shift
    if [ "$#" -ne 2 ]; then
      usage "Wrong number of arguments for scp"
    fi
    download_key
    scp_concourse "$1" "$2"
    ;;
  tunnel)
    shift
    case "$1" in
      ?*:?*:?*)
        download_key
        create_tunnel "$1"
        ;;
      stop)
        download_key
        stop_tunnel
        ;;
      *)
        usage "Invalid format for the tunnel option: '$1'"
        ;;
    esac
    ;;
  *)
    usage "Unknown action '$1'"
    exit 1
    ;;
esac
