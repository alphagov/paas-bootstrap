#!/bin/bash
set -eu -o pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

"${SCRIPT_DIR}/fly_sync_and_login.sh"

state_bucket=gds-paas-${DEPLOY_ENV}-state

generate_vars_file() {
   cat <<EOF
---
aws_account: ${AWS_ACCOUNT}
vagrant_ip: ${VAGRANT_IP}
deploy_env: ${DEPLOY_ENV}
state_bucket: ${state_bucket}
branch_name: ${BRANCH:-master}
aws_region: ${AWS_DEFAULT_REGION:-eu-west-1}
log_level: ${LOG_LEVEL:-}
concourse_hostname: ${CONCOURSE_HOSTNAME}
system_dns_zone_name: ${SYSTEM_DNS_ZONE_NAME}
bosh_az: ${BOSH_AZ:-eu-west-1a}
bosh_manifest_state: bosh-manifest-state-${BOSH_AZ:-eu-west-1a}.json
bosh_fqdn: bosh.${SYSTEM_DNS_ZONE_NAME}
bosh_fqdn_external: bosh-external.${SYSTEM_DNS_ZONE_NAME}
bosh_instance_profile: ${BOSH_INSTANCE_PROFILE}
concourse_instance_type: ${CONCOURSE_INSTANCE_TYPE}
concourse_instance_profile: ${CONCOURSE_INSTANCE_PROFILE}
enable_datadog: ${ENABLE_DATADOG}
datadog_api_key: ${DATADOG_API_KEY:-}
datadog_app_key: ${DATADOG_APP_KEY:-}
enable_collectd_addon: ${ENABLE_COLLECTD_ADDON}
enable_syslog_addon: ${ENABLE_SYSLOG_ADDON}
concourse_auth_duration: ${CONCOURSE_AUTH_DURATION:-5m}
EOF
}

if [ "${ENABLE_DATADOG}" = "true" ] ; then
  eval "$("${SCRIPT_DIR}"/../../scripts/manage-datadog-secrets.sh retrieve)"
fi

generate_vars_file > /dev/null # Check for missing vars

export EXPOSE_PIPELINE=1
for ACTION in create destroy; do
  bash "${SCRIPT_DIR}/deploy-pipeline.sh" \
    "${ACTION}" \
    "${SCRIPT_DIR}/../pipelines/${ACTION}.yml" \
    <(generate_vars_file)
done
