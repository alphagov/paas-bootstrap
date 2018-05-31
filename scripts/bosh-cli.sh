#!/bin/bash

set -eu

BOSH_ID_RSA="$(aws s3 cp "s3://gds-paas-${DEPLOY_ENV}-state/bosh_id_rsa" - | base64)"
export BOSH_ID_RSA

BOSH_CA_CERT="$(aws s3 cp "s3://gds-paas-${DEPLOY_ENV}-state/bosh-CA.crt" -)"
export BOSH_CA_CERT

BOSH_IP=$(aws ec2 describe-instances \
    --filters "Name=key-name,Values=${DEPLOY_ENV}_bosh_ssh_key_pair" \
    --query 'Reservations[].Instances[].PublicIpAddress' --output text)
export BOSH_IP

BOSH_ADMIN_PASSWORD=$(aws s3 cp "s3://gds-paas-${DEPLOY_ENV}-state/bosh-secrets.yml" - | \
    ruby -ryaml -e 'print YAML.load(STDIN)["secrets"]["bosh_admin_password"]')
export BOSH_ADMIN_PASSWORD

docker run \
    -it \
    --rm \
    --env "BOSH_ID_RSA" \
    --env "BOSH_IP" \
    --env "BOSH_ADMIN_PASSWORD" \
    --env "BOSH_ENVIRONMENT=bosh.${SYSTEM_DNS_ZONE_NAME}" \
    --env "BOSH_CA_CERT" \
    --env "BOSH_DEPLOYMENT=${DEPLOY_ENV}" \
    governmentpaas/bosh-shell:0eff5b6a9c092f865a2b19cc4e75a3b539b82fa2
