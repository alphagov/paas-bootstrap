#!/bin/bash
set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

"${SCRIPT_DIR}/fly_sync_and_login.sh"

state_bucket=gds-paas-${DEPLOY_ENV}-state

get_datadog_secrets() {
  # shellcheck disable=SC2154
  secrets_uri="s3://${state_bucket}/datadog-secrets.yml"
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
deploy_env: ${DEPLOY_ENV}
state_bucket: ${state_bucket}
branch_name: ${BRANCH:-master}
aws_region: ${AWS_DEFAULT_REGION:-eu-west-1}
concourse_atc_password: ${CONCOURSE_ATC_PASSWORD}
log_level: ${LOG_LEVEL:-}
concourse_hostname: ${CONCOURSE_HOSTNAME}
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
concourse_auth_duration: ${CONCOURSE_AUTH_DURATION:-5m}
EOF
}

generate_vars_file > /dev/null # Check for missing vars

for ACTION in create destroy; do
  bash "${SCRIPT_DIR}/deploy-pipeline.sh" \
    "${ACTION}" \
    "${SCRIPT_DIR}/../pipelines/${ACTION}.yml" \
    <(generate_vars_file)
done
