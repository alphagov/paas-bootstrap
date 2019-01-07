#!/bin/sh

set -e -u

orig_vars_store=$1
secrets_file=$2
certs_path=$3

template_file="$(mktemp)"
trap 'rm -f "${template_file}"' INT TERM EXIT

cat > "${template_file}" <<EOF
---
admin_password: (( grab secrets.bosh_admin_password ))
hm_password: (( grab secrets.bosh_hm_director_password ))
mbus_bootstrap_password: (( grab secrets.bosh_mbus_bootstrap_password ))

registry_password: (( grab secrets.bosh_registry_password ))

uaa_encryption_key_1: (( grab secrets.bosh_uaa_uaa_encryption_key_1 ))
uaa_jwt_signing_key: (( grab secrets.bosh_uaa_jwt_signing_key ))

uaa_login_client_secret: (( grab secrets.bosh_uaa_login_client_password ))

# Custom secrets
bosh_exporter_password: (( grab secrets.bosh_bosh_exporter_password ))
uaa_postgres_password: (( grab secrets.bosh_uaa_postgres_password ))
bosh_vcap_password: (( grab secrets.bosh_vcap_password ))

# New variables not included:
# - uaa_admin_client_secret:

# Certificates

default_ca:
  ca: (( file "${certs_path}/bosh-CA.crt" ))
  certificate: (( file "${certs_path}/bosh-CA.crt" ))
  private_key: (( file "${certs_path}/bosh-CA.key" ))

director_ssl:
  ca: (( file "${certs_path}/bosh-CA.crt" ))
  certificate: (( file "${certs_path}/bosh_director.crt" ))
  private_key: (( file "${certs_path}/bosh_director.key" ))

nats_ca: (( grab default_ca ))

nats_server_tls:
  ca: (( file "${certs_path}/bosh-CA.crt" ))
  certificate: (( file "${certs_path}/default.nats.bosh-internal.crt" ))
  private_key: (( file "${certs_path}/default.nats.bosh-internal.key" ))

nats_clients_director_tls:
  ca: (( file "${certs_path}/bosh-CA.crt" ))
  certificate: (( file "${certs_path}/default.director.bosh-internal.crt" ))
  private_key: (( file "${certs_path}/default.director.bosh-internal.key" ))

nats_clients_health_monitor_tls:
  ca: (( file "${certs_path}/bosh-CA.crt" ))
  certificate: (( file "${certs_path}/default.hm.bosh-internal.crt" ))
  private_key: (( file "${certs_path}/default.hm.bosh-internal.key" ))

uaa_service_provider_ssl:
  ca: (( file "${certs_path}/bosh-CA.crt" ))
  certificate: (( file "${certs_path}/bosh_uaa_service_provider_ssl.crt" ))
  private_key: (( file "${certs_path}/bosh_uaa_service_provider_ssl.key" ))
uaa_ssl:
  ca: (( file "${certs_path}/bosh-CA.crt" ))
  certificate: (( file "${certs_path}/bosh_uaa.crt" ))
  private_key: (( file "${certs_path}/bosh_uaa.key" ))
EOF

spruce merge \
  --prune certs \
  --prune secrets \
  "${orig_vars_store}" \
  "${secrets_file}" \
  "${template_file}"
