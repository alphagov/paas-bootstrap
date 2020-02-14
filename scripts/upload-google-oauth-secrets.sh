#!/usr/bin/env bash

set -eu

export PASSWORD_STORE_DIR=${GOOGLE_PASSWORD_STORE_DIR}

cat <<EOF | aws s3 cp - "s3://gds-paas-${DEPLOY_ENV}-state/bosh-uaa-google-oauth-secrets.yml"
---
admin_google_oauth_client_id: "${GOOGLE_OAUTH_CLIENT_ID:-"$(pass "google/${MAKEFILE_ENV_TARGET}/oauth/admin_client_id")"}"
admin_google_oauth_client_secret: "${GOOGLE_OAUTH_CLIENT_SECRET:-"$(pass "google/${MAKEFILE_ENV_TARGET}/oauth/admin_client_secret")"}"
EOF

