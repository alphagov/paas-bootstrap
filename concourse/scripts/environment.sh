#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
PROJECT_DIR=$(cd "${SCRIPT_DIR}/../.." && pwd)

hashed_password() {
  echo "$1" | shasum -a 256 | base64 | head -c 32
}

DEPLOY_ENV=${DEPLOY_ENV:-}
if [ -z "${DEPLOY_ENV}" ]; then
  echo "Must specify DEPLOY_ENV environment variable" 1>&2
  exit 1
fi

AWS_ACCOUNT=${AWS_ACCOUNT:-dev}

CONCOURSE_URL="${CONCOURSE_URL:-http://localhost:8080}"
FLY_TARGET="${FLY_TARGET:-${DEPLOY_ENV}-bootstrap}"
FLY_CMD="${PROJECT_DIR}/bin/fly-bootstrap"

CONCOURSE_ATC_USER=${CONCOURSE_ATC_USER:-admin}
if [ -z "${CONCOURSE_ATC_PASSWORD:-}" ]; then
    user_id=$(aws sts get-caller-identity | awk '$1 ~ /UserId/ {print $2}')
    CONCOURSE_ATC_PASSWORD=$(hashed_password "${user_id}")
fi

cat <<EOF
export AWS_ACCOUNT=${AWS_ACCOUNT}
export DEPLOY_ENV=${DEPLOY_ENV}
export CONCOURSE_ATC_USER=${CONCOURSE_ATC_USER}
export CONCOURSE_ATC_PASSWORD=${CONCOURSE_ATC_PASSWORD}
export CONCOURSE_URL=${CONCOURSE_URL}
export FLY_CMD=${FLY_CMD}
export FLY_TARGET=${FLY_TARGET}
EOF
