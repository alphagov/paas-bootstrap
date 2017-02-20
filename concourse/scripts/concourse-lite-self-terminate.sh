#!/bin/bash
set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

"${SCRIPT_DIR}/fly_sync_and_login.sh"

pipeline="self-terminate"
config="${SCRIPT_DIR}/../pipelines/concourse-lite-self-terminate.yml"

generate_vars_file() {
  cat <<EOF
---
vagrant_ssh_key_name: ${VAGRANT_SSH_KEY_NAME}
EOF
}

generate_vars_file > /dev/null # Check for missing vars

bash "${SCRIPT_DIR}/deploy-pipeline.sh" \
   "${pipeline}" "${config}" <(generate_vars_file)
