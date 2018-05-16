#!/bin/sh
set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

help() {
  cat <<EOF
Tries to retrieve logit credentials from the S3 object logit-secrets.yml.
If the object or the bucket does not exists, it will try to retrieve the
credentials from the environment or paas-pass. It will print the variables
to be evaluated.

It can also upload the S3 object with the credentials from the environment
or paas-pass.

Usage:

  AWS_ACCOUNT=dev LOGIT_PASSWORD_STORE_DIR=~/.paas-pass DEPLOY_ENV=hector
    ./scripts/manage-logit-secrets.sh upload

  eval \$(
    AWS_ACCOUNT=dev LOGIT_PASSWORD_STORE_DIR=~/.paas-pass DEPLOY_ENV=hector
    ./scripts/manage-logit-secrets.sh retrieve
  )

EOF
}

val_from_yaml() {
  "${SCRIPT_DIR}"/../concourse/scripts/val_from_yaml.rb "$1" "$2"
}

setup_env() {
  export PASSWORD_STORE_DIR=${LOGIT_PASSWORD_STORE_DIR}
  secrets_uri="s3://gds-paas-${DEPLOY_ENV}-state/logit-secrets.yml"
}

get_creds_from_env_or_pass() {
  setup_env
  LOGIT_SYSLOG_ADDRESS="${LOGIT_SYSLOG_ADDRESS:-$(pass "logit/${AWS_ACCOUNT}/syslog_address")}"
  LOGIT_SYSLOG_PORT="${LOGIT_SYSLOG_PORT:-$(pass "logit/${AWS_ACCOUNT}/syslog_port")}"
  LOGIT_CA_CERT="${LOGIT_CA_CERT:-$(pass "logit/${AWS_ACCOUNT}/ca_cert")}"
}

upload() {
  setup_env
  get_creds_from_env_or_pass
  secrets_file=$(mktemp secrets.yml.XXXXXX)
  trap 'rm  "${secrets_file}"' EXIT

  cat > "${secrets_file}" << EOF
---
logit_syslog_address: ${LOGIT_SYSLOG_ADDRESS}
logit_syslog_port: ${LOGIT_SYSLOG_PORT}
logit_ca_cert: |
$(echo "${LOGIT_CA_CERT}" | sed 's/^/  /')
EOF

  aws s3 cp "${secrets_file}" "${secrets_uri}"
}

retrieve() {
  setup_env
  if aws s3 ls "${secrets_uri}" > /dev/null ; then
    secrets_file=$(mktemp -t logit-secrets.XXXXXX)
    trap 'rm  "${secrets_file}"' EXIT

    aws s3 cp "${secrets_uri}" "${secrets_file}" 1>&2
    LOGIT_SYSLOG_ADDRESS="${LOGIT_SYSLOG_ADDRESS:-$(val_from_yaml logit_syslog_address "${secrets_file}")}"
    LOGIT_SYSLOG_PORT="${LOGIT_SYSLOG_PORT:-$(val_from_yaml logit_syslog_port "${secrets_file}")}"
    LOGIT_CA_CERT="${LOGIT_CA_CERT:-$(val_from_yaml logit_ca_cert "${secrets_file}")}"
  else
    echo "Warning: Cannot retrieve logit secrets from S3. Retriving from environment or from pass." 1>&2
    get_creds_from_env_or_pass
  fi

  if [ -z "${LOGIT_SYSLOG_ADDRESS}" ] || [ -z "${LOGIT_SYSLOG_PORT}" ] || [ -z "${LOGIT_CA_CERT}" ] ; then
    echo "\$LOGIT_SYSLOG_ADDRESS or \$LOGIT_SYSLOG_PORT or \$LOGIT_CA_CERT not set, failing" 1>&2
  else
    echo "export LOGIT_SYSLOG_ADDRESS=\"${LOGIT_SYSLOG_ADDRESS}\""
    echo "export LOGIT_SYSLOG_PORT=\"${LOGIT_SYSLOG_PORT}\""
    echo "export LOGIT_CA_CERT=\"${LOGIT_CA_CERT}\""
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
