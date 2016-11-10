#!/bin/bash
set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

"${SCRIPT_DIR}/fly_sync_and_login.sh"

env=${DEPLOY_ENV}

get_datadog_secrets() {
  # shellcheck disable=SC2154
  secrets_uri="s3://gds-paas-${env}-bootstrap/datadog-secrets.yml"
  export datadog_api_key
  export datadog_app_key
  if aws s3 ls "${secrets_uri}" > /dev/null ; then
    secrets_file=$(mktemp -t datadog-secrets.XXXXXX)

    aws s3 cp "${secrets_uri}" "${secrets_file}"
    datadog_api_key=$("${SCRIPT_DIR}"/val_from_yaml.rb datadog_api_key "${secrets_file}")
    datadog_app_key=$("${SCRIPT_DIR}"/val_from_yaml.rb datadog_app_key "${secrets_file}")

    rm -f "${secrets_file}"
  fi
}
get_datadog_secrets

generate_vars_file() {
   cat <<EOF
---
aws_account: ${AWS_ACCOUNT}
vagrant_ip: ${VAGRANT_IP}
deploy_env: ${env}
state_bucket: gds-paas-${env}-bootstrap
branch_name: ${BRANCH:-master}
aws_region: ${AWS_DEFAULT_REGION:-eu-west-1}
concourse_atc_password: ${CONCOURSE_ATC_PASSWORD}
log_level: ${LOG_LEVEL:-}
system_dns_zone_name: ${SYSTEM_DNS_ZONE_NAME}
bosh_az: ${BOSH_AZ:-eu-west-1a}
bosh_manifest_state: bosh-manifest-state-${BOSH_AZ:-eu-west-1a}.json
bosh_fqdn: bosh.${SYSTEM_DNS_ZONE_NAME}
bosh_fqdn_external: bosh-external.${SYSTEM_DNS_ZONE_NAME}
concourse_atc_password: ${CONCOURSE_ATC_PASSWORD}
bosh_instance_profile: ${BOSH_INSTANCE_PROFILE}
concourse_instance_profile: ${CONCOURSE_INSTANCE_PROFILE}
enable_datadog: ${ENABLE_DATADOG}
datadog_api_key: ${datadog_api_key:-}
EOF
}

generate_vars_file > /dev/null # Check for missing vars

for ACTION in create destroy; do
  bash "${SCRIPT_DIR}/deploy-pipeline.sh" \
    "${env}" "${ACTION}" \
    "${SCRIPT_DIR}/../pipelines/${ACTION}.yml" \
    <(generate_vars_file)
done
