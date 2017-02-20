#!/bin/bash

set -e

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
cd "$SCRIPT_DIR"

# Load environment variables
# shellcheck disable=SC2091
$("${SCRIPT_DIR}/../concourse/scripts/environment.sh")

read -r -p "This is a destructive operation, are you sure you want to do this [y/N]? "
if ! [[ ${REPLY:0:1} == [Yy] ]]; then
  exit 1
fi

echo "About to delete bootstrap ssh pub key from AWS..."
aws ec2 delete-key-pair --key-name "${VAGRANT_SSH_KEY_NAME}"

if [[ -f ${VAGRANT_SSH_KEY} ]] ; then
 echo "About to delete bootstrap ssh private key from disk..."
 rm "${VAGRANT_SSH_KEY}"
fi
unset VAGRANT_SSH_KEY

echo "About to vagrant destroy..."
vagrant destroy -f
