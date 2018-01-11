#!/bin/bash

set -eu

BOSH_ID_RSA="$(aws s3 cp "s3://gds-paas-${DEPLOY_ENV}-state/bosh_id_rsa" - | base64)"
export BOSH_ID_RSA

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
    --env "BOSH_DEPLOYMENT=${DEPLOY_ENV}" \
    governmentpaas/bosh-shell:2b4604fe69274908af304c15f28ca8dd657b0221
