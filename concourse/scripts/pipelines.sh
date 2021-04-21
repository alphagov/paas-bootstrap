#!/bin/bash
set -eu -o pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

"${SCRIPT_DIR}/fly_sync_and_login.sh"

state_bucket=gds-paas-${DEPLOY_ENV}-state

case $DEPLOY_ENV in
prod-lon)
  # Flag of Greater London
  BACKGROUND_IMAGE_URL="https://upload.wikimedia.org/wikipedia/commons/2/25/Flag_of_Greater_London.svg"
  ;;
prod)
  # Flag of the City of Dublin
  BACKGROUND_IMAGE_URL="https://upload.wikimedia.org/wikipedia/commons/thumb/8/8f/IRL_Dublin_flag.svg/1500px-IRL_Dublin_flag.svg.png"
  ;;
stg-lon)
  # The Minack Theatre in Cornwall
  BACKGROUND_IMAGE_URL="https://upload.wikimedia.org/wikipedia/commons/1/16/Minack_Theatre.jpg"
  ;;
*)
  # A large inflatable duck
  BACKGROUND_IMAGE_URL="https://si.wsj.net/public/resources/images/BN-EX226_duck_G_20141008024653.jpg"
  ;;
esac


generate_vars_file() {
   cat <<EOF
---
makefile_env_target: ${MAKEFILE_ENV_TARGET}
aws_account: ${AWS_ACCOUNT}
deploy_env: ${DEPLOY_ENV}
state_bucket: ${state_bucket}
branch_name: ${BRANCH:-main}
aws_region: ${AWS_DEFAULT_REGION:-eu-west-1}
log_level: ${LOG_LEVEL:-}
concourse_hostname: ${CONCOURSE_HOSTNAME}
concourse_url: ${CONCOURSE_URL}
system_dns_zone_name: ${SYSTEM_DNS_ZONE_NAME}
system_dns_zone_id: ${SYSTEM_DNS_ZONE_ID}
bosh_az: ${BOSH_AZ:-${AWS_DEFAULT_REGION}a}
bosh_manifest_state: bosh-manifest-state-${BOSH_AZ:-${AWS_DEFAULT_REGION}a}.json
bosh_fqdn: ${BOSH_FQDN}
bosh_fqdn_external: ${BOSH_FQDN_EXTERNAL}
bosh_login_host: ${BOSH_LOGIN_HOST}
bosh_instance_profile: ${BOSH_INSTANCE_PROFILE}
skip_commit_verification: ${SKIP_COMMIT_VERIFICATION:-}
self_update_pipeline: ${SELF_UPDATE_PIPELINE:-true}
target_concourse: ${TARGET_CONCOURSE}
concourse_type: ${CONCOURSE_TYPE}
concourse_instance_type: ${CONCOURSE_INSTANCE_TYPE}
concourse_instance_profile: ${CONCOURSE_INSTANCE_PROFILE}
concourse_web_instances: ${CONCOURSE_WEB_INSTANCES}
concourse_worker_instances: ${CONCOURSE_WORKER_INSTANCES}
enable_github: ${ENABLE_GITHUB}
github_client_id: ${GITHUB_CLIENT_ID:-}
github_client_secret: ${GITHUB_CLIENT_SECRET:-}
concourse_auth_duration: ${CONCOURSE_AUTH_DURATION:-5m}
background_image_url: ${BACKGROUND_IMAGE_URL}
EOF
}

if [ "${ENABLE_GITHUB}" = "true" ] ; then
  eval "$("${SCRIPT_DIR}"/../../scripts/upload-secrets/manage-github-secrets.sh retrieve)"
fi

generate_vars_file > /dev/null # Check for missing vars

upload_pipeline() {
  bash "${SCRIPT_DIR}/deploy-pipeline.sh" \
    "${pipeline_name}" \
    "${SCRIPT_DIR}/../pipelines/${pipeline_name}.yml" \
    <(generate_vars_file)
}

remove_pipeline() {
  ${FLY_CMD} -t "${FLY_TARGET}" destroy-pipeline --pipeline "${pipeline_name}" --non-interactive || true
}

update_pipeline() {
  pipeline_name="$1"

  case "$pipeline_name" in
    create-bosh-concourse)
      upload_pipeline
    ;;
    destroy-bosh-concourse)
      if [ "${ENABLE_DESTROY:-}" == 'true' ] && [ "${TARGET_CONCOURSE}" == 'bootstrap' ]; then
        upload_pipeline
      else
        remove_pipeline
      fi
    ;;
    *)
      echo "ERROR: Unknown pipeline definition: $pipeline_name"
      exit 1
    ;;
  esac
}

export EXPOSE_PIPELINE=1
pipelines_to_update="create-bosh-concourse destroy-bosh-concourse"
for p in $pipelines_to_update; do
  update_pipeline "$p"
done
