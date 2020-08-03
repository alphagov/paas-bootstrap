#!/usr/bin/env bash

set -eu

export PASSWORD_STORE_DIR=${CYBER_PASSWORD_STORE_DIR}

cat <<EOF | aws s3 cp - "s3://gds-paas-${DEPLOY_ENV}-state/bosh-cyber-secrets.yml"
---
bosh_auditor_splunk_hec_token: "${BOSH_AUDITOR_SPLUNK_HEC_TOKEN:-"$(pass "splunk/${MAKEFILE_ENV_TARGET}/hec_token")"}"
csls_kinesis_destination_arn: "${CSLS_KINESIS_DESTINATION_ARN:-"$(pass "cyber/${MAKEFILE_ENV_TARGET}/csls_kinesis_destination_arn")"}"
EOF
