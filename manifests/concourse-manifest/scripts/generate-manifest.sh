#!/bin/sh

set -eu

PAAS_BOOTSTRAP_DIR=${PAAS_BOOTSTRAP_DIR:-paas-bootstrap}
WORKDIR=${WORKDIR:-.}

github_auth_files=""
if [ "${ENABLE_GITHUB}" = "true" ] ; then
  github_auth_files="${github_auth_files} ${PAAS_BOOTSTRAP_DIR}/manifests/concourse-manifest/github_auth/config.yml"
  if [ "${AWS_ACCOUNT}" = "dev" ] || [ "${AWS_ACCOUNT}" = "ci" ]; then
    github_auth_files="${github_auth_files} ${PAAS_BOOTSTRAP_DIR}/manifests/concourse-manifest/github_auth/dev_ci_additional_users.yml"
  fi
fi

# shellcheck disable=SC2086
spruce merge \
  --prune meta \
  --prune secrets \
  --prune terraform_outputs \
  "${PAAS_BOOTSTRAP_DIR}/manifests/concourse-manifest/concourse-base.yml" \
  "${PAAS_BOOTSTRAP_DIR}/manifests/concourse-manifest/operations.d/010-x-frame-options.yml" \
  "${WORKDIR}/bosh-secrets/bosh-secrets.yml" \
  "${WORKDIR}/terraform-outputs/concourse-terraform-outputs.yml" \
  "${WORKDIR}/terraform-outputs/vpc-terraform-outputs.yml" \
  "${WORKDIR}/terraform-outputs/bosh-terraform-outputs.yml" \
  ${github_auth_files}
