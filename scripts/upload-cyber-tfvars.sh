#!/bin/sh
set -eu

export PASSWORD_STORE_DIR=${CYBER_PASSWORD_STORE_DIR}

cat << EOF | aws s3 cp - "s3://gds-paas-${DEPLOY_ENV}-state/bootstrap-cyber.tfvars"
csls_kinesis_destination_arn = "$(pass "/cyber/${MAKEFILE_ENV_TARGET}/csls_kinesis_destination_arn")"
EOF
