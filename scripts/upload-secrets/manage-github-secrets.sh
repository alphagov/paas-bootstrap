#!/bin/sh
set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

help() {
  cat <<EOF
Tries to retrieve github credentials from the S3 object github-secrets.yml.
If the object or the bucket does not exists, it will try to retrieve the
credentials from the environment or paas-pass. It will print the variables
to be evaluated.

It can also upload the S3 object with the credentials from the environment
or paas-pass.

You should run it via the Makefile target to set up the necessary environment.
However, if you want to run it directly:

  MAKEFILE_ENV_TARGET=dev GITHUB_PASSWORD_STORE_DIR=~/.paas-pass DEPLOY_ENV=leeporte
    ./scripts/upload-secrets/manage-github-secrets.sh upload

  eval \$(
    MAKEFILE_ENV_TARGET=dev GITHUB_PASSWORD_STORE_DIR=~/.paas-pass DEPLOY_ENV=leeporte
    ./scripts/upload-secrets/manage-github-secrets.sh retrieve
  )

EOF
}

val_from_yaml() {
  "${SCRIPT_DIR}"/../../concourse/scripts/val_from_yaml.rb "$1" "$2"
}

setup_env() {
  export PASSWORD_STORE_DIR=${GITHUB_PASSWORD_STORE_DIR}
  secrets_uri="s3://gds-paas-${DEPLOY_ENV}-state/github-oauth-secrets.yml"
}

get_creds_from_env_or_pass() {
  setup_env
  GITHUB_CLIENT_ID="${GITHUB_CLIENT_ID:-$(pass "github.com/concourse/${DEPLOY_ENV}/client_id")}"
  GITHUB_CLIENT_SECRET="${GITHUB_CLIENT_SECRET:-$(pass "github.com/concourse/${DEPLOY_ENV}/client_secret")}"
}

upload() {
  setup_env
  get_creds_from_env_or_pass
  secrets_file=$(mktemp secrets.yml.XXXXXX)
  trap 'rm  "${secrets_file}"' EXIT

  cat > "${secrets_file}" << EOF
---
github_client_id: ${GITHUB_CLIENT_ID}
github_client_secret: ${GITHUB_CLIENT_SECRET}
EOF

  aws s3 cp "${secrets_file}" "${secrets_uri}"
}

retrieve() {
  setup_env
  if aws s3 ls "${secrets_uri}" > /dev/null ; then
    secrets_file=$(mktemp -t github-oauth-secrets.XXXXXX)
    trap 'rm  "${secrets_file}"' EXIT

    aws s3 cp "${secrets_uri}" "${secrets_file}" 1>&2
    GITHUB_CLIENT_ID="${GITHUB_CLIENT_ID:-$(val_from_yaml github_client_id "${secrets_file}")}"
    GITHUB_CLIENT_SECRET="${GITHUB_CLIENT_SECRET:-$(val_from_yaml github_client_secret "${secrets_file}")}"
  else
    echo "Warning: Cannot retrieve github secrets from S3. Retriving from environment or from pass." 1>&2
    get_creds_from_env_or_pass
  fi

  if [ -z "${GITHUB_CLIENT_ID}" ] || [ -z "${GITHUB_CLIENT_SECRET}" ] ; then
    echo "\$GITHUB_CLIENT_ID or \$GITHUB_CLIENT_SECRET not set, failing" 1>&2
  else
    echo "export GITHUB_CLIENT_ID=\"${GITHUB_CLIENT_ID}\""
    echo "export GITHUB_CLIENT_SECRET=\"${GITHUB_CLIENT_SECRET}\""
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

