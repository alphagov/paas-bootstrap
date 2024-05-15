#!/bin/sh

set -eu

export DEBIAN_FRONTEND=noninteractive

echo "Waiting for cloud-init to update /etc/apt/sources.list .." >&2
until grep -q ec2.archive.ubuntu.com /etc/apt/sources.list; do
  sleep 2
  echo ".. still waiting .." >&2
done
echo ".. update complete." >&2

sudo -E apt-get update && sudo -E apt-get install docker-compose -y

cd /vagrant

# shellcheck disable=SC2091
$(./environment.sh)

# Expose settings as the envvars which the upstream docker-compose file expects
export CONCOURSE_POSTGRES_DATABASE="$CONCOURSE_DATABASE_NAME"
export CONCOURSE_POSTGRES_USER="$CONCOURSE_DATABASE_USER"
export CONCOURSE_POSTGRES_PASSWORD="$CONCOURSE_DATABASE_PASS"
export CONCOURSE_ADD_LOCAL_USER="${CONCOURSE_WEB_USER}:${CONCOURSE_WEB_PASSWORD}"
export CONCOURSE_EXTERNAL_URL="$CONCOURSE_URL"

mkdir -p /tmp/keys

sudo docker run --rm -v /tmp/keys:/keys concourse/concourse:7.11.2 \
  generate-key -t rsa -f /keys/session_signing_key

sudo docker run --rm -v /tmp/keys:/keys concourse/concourse:7.11.2 \
  generate-key -t ssh -f /keys/tsa_host_key

sudo docker run --rm -v /tmp/keys:/keys concourse/concourse:7.11.2 \
  generate-key -t ssh -f /keys/worker_key

sudo -E docker-compose up -d
