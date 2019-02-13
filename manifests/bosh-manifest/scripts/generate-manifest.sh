#!/bin/bash

set -euo pipefail

PAAS_BOOTSTRAP_DIR=${PAAS_BOOTSTRAP_DIR:-paas-bootstrap}
BOSH_DEPLOYMENT_DIR=${PAAS_BOOTSTRAP_DIR}/manifests/bosh-manifest/upstream
WORKDIR=${WORKDIR:-.}

opsfile_args=""
for i in "${PAAS_BOOTSTRAP_DIR}"/manifests/bosh-manifest/operations.d/*.yml; do
  opsfile_args+="-o $i "
done

vars_store_args=""
if [ -n "${VARS_STORE:-}" ]; then
  vars_store_args=" --var-errs --vars-store ${VARS_STORE}"
fi

variables_file="$(mktemp)"
trap 'rm -f "${variables_file}"' INT TERM EXIT

bosh interpolate - \
  --var-errs \
  --vars-file "${WORKDIR}/bosh-secrets/bosh-secrets.yml" \
  --vars-file "${WORKDIR}/terraform-outputs/bosh-terraform-outputs.yml" \
  --vars-file "${WORKDIR}/terraform-outputs/vpc-terraform-outputs.yml" \
  --var-file="default_ca.certificate=${WORKDIR}/certs/bosh-CA.crt" \
  --var-file="default_ca.private_key=${WORKDIR}/certs/bosh-CA.key" \
  > "${variables_file}" \
  <<EOF
---
director_name: ${DEPLOY_ENV}
deploy_env: ${DEPLOY_ENV}
system_domain: ${SYSTEM_DNS_ZONE_NAME}
aws_account: ${AWS_ACCOUNT}
bosh_fqdn: ${BOSH_FQDN}
bosh_fqdn_external: ${BOSH_FQDN_EXTERNAL}

iam_instance_profile: ${BOSH_INSTANCE_PROFILE}

internal_cidr: ((terraform_outputs_bosh_subnet_cidr))
internal_gw: ((terraform_outputs_bosh_default_gw))
internal_ip: ((terraform_outputs_microbosh_static_private_ip))
external_ip: ((terraform_outputs_microbosh_static_public_ip))

az: ((terraform_outputs_bosh_az))
region: ((terraform_outputs_region))
subnet_id: ((terraform_outputs_bosh_subnet_id))

default_key_name: ((terraform_outputs_key_pair_name))

default_security_groups:
- ((terraform_outputs_bosh_managed_security_group))

bosh_security_groups:
- ((terraform_outputs_bosh_security_group))
- ((terraform_outputs_ssh_security_group))

external_db_host: ((terraform_outputs_bosh_db_address))
external_db_port: ((terraform_outputs_bosh_db_port))
external_db_user: ((terraform_outputs_bosh_db_username))
external_db_password: ((secrets.bosh_postgres_password))
external_db_name: ((terraform_outputs_bosh_db_dbname))
external_db_adapter: "postgres"

bosh_blobstore_bucket_name: ((terraform_outputs_bosh_blobstore_bucket_name))

private_key: ".ssh/id_rsa"

default_ca:
  ca: ((default_ca.certificate))
  certificate: ((default_ca.certificate))
  private_key: ((default_ca.private_key))

nats_ca:
  ca: ((default_ca.certificate))
  certificate: ((default_ca.certificate))
  private_key: ((default_ca.private_key))

vcap_password: ((secrets.vcap_password))
EOF


# shellcheck disable=SC2086
bosh interpolate \
  --vars-file="${variables_file}" \
  --vars-file="${PAAS_BOOTSTRAP_DIR}/manifests/bosh-manifest/variables.yml" \
  ${opsfile_args} \
  ${vars_store_args} \
    "${BOSH_DEPLOYMENT_DIR}/bosh.yml"
