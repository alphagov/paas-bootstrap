#!/bin/bash

set -euo pipefail

PAAS_BOOTSTRAP_DIR=${PAAS_BOOTSTRAP_DIR:-paas-bootstrap}
RUNTIME_CONFIG_DIR=${PAAS_BOOTSTRAP_DIR}/manifests/runtime-config
WORKDIR=${WORKDIR:-.}

opsfile_args=""

unix_users_ops_file="${WORKDIR}/unix-users-ops-file/unix-users-ops-file.yml"
if [ -f "$unix_users_ops_file" ]; then
  opsfile_args+="-o $unix_users_ops_file "
else
  >&2 echo "Could not find $unix_users_ops_file. Aborting."
  exit 1
fi

# shellcheck disable=SC2086
bosh interpolate \
  ${opsfile_args} \
    "${RUNTIME_CONFIG_DIR}/runtime-config-base.yml"
