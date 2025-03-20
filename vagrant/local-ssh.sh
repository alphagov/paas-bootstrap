#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
PROJECT_DIR=$(cd "${SCRIPT_DIR}/.." && pwd)
cd "$SCRIPT_DIR"

# Load environment variables
# shellcheck disable=SC2091
$("${PROJECT_DIR}/concourse/scripts/environment.sh")

CONCOURSE_WEB_USER="admin"
CONCOURSE_WEB_PASSWORD="$(
  aws sts get-caller-identity \
  | awk '$1 ~ /UserId/ {sub(/:.*$/, "", $2); print $2}' \
  | shasum -a 256 \
  | base64 \
  | head -c 32
)"
export CONCOURSE_WEB_USER CONCOURSE_WEB_PASSWORD

export VAGRANT_DEFAULT_PROVIDER="aws"
export VAGRANT_BOX_NAME="aws_vagrant_box"

if ! vagrant status 2>&1 | grep "running\ (aws)" >/dev/null; then
  echo "Concourse Bootstrap VM is not running."
  if aws ec2 describe-key-pairs --key-name "${VAGRANT_SSH_KEY_NAME}" >/dev/null 2>&1 ; then
    echo "Cleaning up old key pair..."
    aws ec2 delete-key-pair --key-name "${VAGRANT_SSH_KEY_NAME}"
  fi
  echo "Creating new key pair..."
  # Create the key pair online.
  aws ec2 create-key-pair --key-name "${VAGRANT_SSH_KEY_NAME}" | jq -r ".KeyMaterial" > "${VAGRANT_SSH_KEY}"

  # Secure the local key.
  chmod 600 "${VAGRANT_SSH_KEY}"
fi

# Install aws dummy box if not present
if ! vagrant box list | grep -qe "^${VAGRANT_BOX_NAME} "; then
  vagrant box add "${VAGRANT_BOX_NAME}" \
    https://github.com/mitchellh/vagrant-aws/raw/74021d7c9fbc519307d661656f6ce96eeb61153c/dummy.box
fi

vagrant up

if ! pgrep -f "ssh.*${VAGRANT_SSH_KEY_NAME}.*-L 8080:127.0.0.1:8080 -fN" >/dev/null; then
  echo "Setting up SSH tunnel to concourse..."
  vagrant ssh -- -L 8080:127.0.0.1:8080 -fN
else
  echo "SSH tunnel to concourse already running."
fi
timeout=180
deadline=$(($(date +%s) + timeout))
echo -n "Waiting for concourse to start for ${timeout}s..."

while ! curl -f -qs http://127.0.0.1:8080/login -o /dev/null; do
  sleep 5
  echo -n .
  if [ "$(date +%s)" -gt ${deadline} ] ; then
     echo "Could not reach concourse login page via tunnel for ${timeout} seconds. Aborting."
     exit 1
  fi
done

echo
echo "Succeeded connecting to concourse."

echo
echo "Concourse auth is ${CONCOURSE_WEB_USER} : ${CONCOURSE_WEB_PASSWORD}"
echo "Concourse URL is ${CONCOURSE_URL}"
echo
echo "About to upload pipelines..."

"${PROJECT_DIR}/concourse/scripts/pipelines.sh"
"${PROJECT_DIR}/concourse/scripts/concourse-lite-self-terminate.sh"
