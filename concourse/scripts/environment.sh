#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
PROJECT_DIR=$(cd "${SCRIPT_DIR}/../.." && pwd)

DEPLOY_ENV=${DEPLOY_ENV:-}
if [ -z "${DEPLOY_ENV}" ]; then
  echo "Must specify DEPLOY_ENV environment variable" 1>&2
  exit 1
fi

BOSH_FQDN="bosh.${SYSTEM_DNS_ZONE_NAME}"
BOSH_FQDN_EXTERNAL="bosh-external.${SYSTEM_DNS_ZONE_NAME}"
case "${TARGET_CONCOURSE}" in
  bootstrap)
    CONCOURSE_URL="${CONCOURSE_URL:-http://localhost:8080}"
    FLY_TARGET="${FLY_TARGET:-${DEPLOY_ENV}-bootstrap}"
    FLY_CMD="${PROJECT_DIR}/bin/fly-bootstrap"
    BOSH_LOGIN_HOST=${BOSH_FQDN_EXTERNAL}
    ;;
  deployer-concourse|build-concourse)
    CONCOURSE_URL="https://${CONCOURSE_HOSTNAME}.${SYSTEM_DNS_ZONE_NAME}"
    FLY_TARGET="${FLY_TARGET:-$DEPLOY_ENV}"
    FLY_CMD="${PROJECT_DIR}/bin/fly"
    BOSH_LOGIN_HOST=${BOSH_FQDN}
    ;;
  *)
    echo "Unrecognized TARGET_CONCOURSE: '${TARGET_CONCOURSE}'. Must be (bootstrap|deployer-concourse|build-concourse)" 1>&2
    exit 1
    ;;
esac

CONCOURSE_DATABASE_NAME="concourse"
CONCOURSE_DATABASE_USER="$(openssl rand -hex 10)"
CONCOURSE_DATABASE_PASS="$(openssl rand -hex 32)"

cat <<EOF
export AWS_ACCOUNT=${AWS_ACCOUNT}
export DEPLOY_ENV=${DEPLOY_ENV}
export CONCOURSE_URL=${CONCOURSE_URL}
export CONCOURSE_DATABASE_NAME=${CONCOURSE_DATABASE_NAME}
export CONCOURSE_DATABASE_USER=${CONCOURSE_DATABASE_USER}
export CONCOURSE_DATABASE_PASS=${CONCOURSE_DATABASE_PASS}
export BOSH_LOGIN_HOST=${BOSH_LOGIN_HOST}
export BOSH_FQDN=${BOSH_FQDN}
export BOSH_FQDN_EXTERNAL=${BOSH_FQDN_EXTERNAL}
export VAGRANT_SSH_KEY=${PROJECT_DIR}/${DEPLOY_ENV}-vagrant-bootstrap-concourse
export FLY_CMD=${FLY_CMD}
export FLY_TARGET=${FLY_TARGET}
EOF
