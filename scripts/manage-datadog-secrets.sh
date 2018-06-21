#!/bin/sh
set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

help() {
  cat <<EOF
Tries to retrieve datadog credentials from the S3 object datadog-secrets.yml.
If the object or the bucket does not exists, it will try to retrieve the
credentials from the environment or paas-pass. It will print the variables
to be evaluated.

It can also upload the S3 object with the credentials from the environment
or paas-pass.

You should run it via the Makefile target to set up the necessary environment.
However, if you want to run it directly:

  MAKEFILE_ENV_TARGET=dev DATADOG_PASSWORD_STORE_DIR=~/.paas-pass DEPLOY_ENV=hector
    ./scripts/manage-datadog-secrets.sh upload

  eval \$(
    MAKEFILE_ENV_TARGET=dev DATADOG_PASSWORD_STORE_DIR=~/.paas-pass DEPLOY_ENV=hector
    ./scripts/manage-datadog-secrets.sh retrieve
  )

EOF
}

val_from_yaml() {
  "${SCRIPT_DIR}"/../concourse/scripts/val_from_yaml.rb "$1" "$2"
}

setup_env() {
  export PASSWORD_STORE_DIR=${DATADOG_PASSWORD_STORE_DIR}
  secrets_uri="s3://gds-paas-${DEPLOY_ENV}-state/datadog-secrets.yml"
}

get_creds_from_env_or_pass() {
  setup_env
  DATADOG_API_KEY="${DATADOG_API_KEY:-$(pass "datadog/${MAKEFILE_ENV_TARGET}/datadog_api_key")}"
  DATADOG_APP_KEY="${DATADOG_APP_KEY:-$(pass "datadog/${MAKEFILE_ENV_TARGET}/datadog_app_key")}"
}

upload() {
  setup_env
  get_creds_from_env_or_pass
  secrets_file=$(mktemp secrets.yml.XXXXXX)
  trap 'rm  "${secrets_file}"' EXIT

  cat > "${secrets_file}" << EOF
---
datadog_api_key: ${DATADOG_API_KEY}
datadog_app_key: ${DATADOG_APP_KEY}
EOF

  aws s3 cp "${secrets_file}" "${secrets_uri}"
}

retrieve() {
  setup_env
  if aws s3 ls "${secrets_uri}" > /dev/null ; then
    secrets_file=$(mktemp -t datadog-secrets.XXXXXX)
    trap 'rm  "${secrets_file}"' EXIT

    aws s3 cp "${secrets_uri}" "${secrets_file}" 1>&2
    DATADOG_API_KEY="${DATADOG_API_KEY:-$(val_from_yaml datadog_api_key "${secrets_file}")}"
    DATADOG_APP_KEY="${DATADOG_APP_KEY:-$(val_from_yaml datadog_app_key "${secrets_file}")}"
  else
    echo "Warning: Cannot retrieve datadog secrets from S3. Retriving from environment or from pass." 1>&2
    get_creds_from_env_or_pass
  fi

  if [ -z "${DATADOG_API_KEY}" ] || [ -z "${DATADOG_APP_KEY}" ] ; then
    echo "\$DATADOG_API_KEY or \$DATADOG_APP_KEY not set, failing" 1>&2
  else
    echo "export DATADOG_API_KEY=\"${DATADOG_API_KEY}\""
    echo "export DATADOG_APP_KEY=\"${DATADOG_APP_KEY}\""
  fi
}

case ${1:-} in
  upload)
    upload
  ;;
  retrieve)
    retrieve
  ;;
  *)
    help
  ;;
esac
