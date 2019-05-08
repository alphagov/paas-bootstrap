#!/bin/sh

set -eu

echo "Waiting for cloud-init to update /etc/apt/sources.list .." >&2
until grep -q ec2.archive.ubuntu.com /etc/apt/sources.list; do
  sleep 2
  echo ".. still waiting .." >&2
done
echo ".. update complete." >&2

sudo apt-get update && sudo apt-get install docker-compose -y

cd /vagrant

# shellcheck disable=SC2091
$(./environment.sh)

# Expose settings as the envvars which the upstream docker-compose file expects
export CONCOURSE_POSTGRES_DATABASE="$CONCOURSE_DATABASE_NAME"
export CONCOURSE_POSTGRES_USER="$CONCOURSE_DATABASE_USER"
export CONCOURSE_POSTGRES_PASSWORD="$CONCOURSE_DATABASE_PASS"
export CONCOURSE_ADD_LOCAL_USER="${CONCOURSE_WEB_USER}:${CONCOURSE_WEB_PASSWORD}"
export CONCOURSE_EXTERNAL_URL="$CONCOURSE_URL"

sudo -E docker-compose up -d
