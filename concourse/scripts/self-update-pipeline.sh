#!/bin/bash
#
# Required variables are:
# - DEPLOY_ENV
# - MAKEFILE_ENV_TARGET
# - SELF_UPDATE_PIPELINE
#
# Optional variables:
# - BRANCH

set -u
set -e

if [ "${TARGET_CONCOURSE}" == "bootstrap" ]; then
  echo "Bootstrap Concourse should not self-update, as this requires access to \`aws sts get-caller-identity\`. Skipping."
  exit 0
fi

if [ "${SELF_UPDATE_PIPELINE}" == "true" ]; then
  echo "Self update pipeline is enabled. Updating. (set SELF_UPDATE_PIPELINE=false to disable)"

  make -C ./paas-bootstrap "${MAKEFILE_ENV_TARGET}" "${CONCOURSE_TYPE}" pipelines
else
  echo "Self update pipeline is disabled. Skipping. (set SELF_UPDATE_PIPELINE=true to enable)"
fi
