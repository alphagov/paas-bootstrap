#!/bin/sh

set -e
set -u

CA_NAME="bosh-CA"

# List of certs to generate
# Format:
#
# <name_cert>,<domain1>[,domain2,domain3,...]
#
# Note: ALWAYS add a comma after <name_cert>, even if there are no domains
#
CERTS_TO_GENERATE="
default.nats.bosh-internal,bosh.${SYSTEM_DNS_ZONE_NAME}
default.director.bosh-internal,
default.hm.bosh-internal,
bosh_director,bosh.${SYSTEM_DNS_ZONE_NAME},bosh-external.${SYSTEM_DNS_ZONE_NAME}
bosh_uaa,bosh.${SYSTEM_DNS_ZONE_NAME}
bosh_uaa_service_provider_ssl,bosh.${SYSTEM_DNS_ZONE_NAME}
"

generate_cert() {
  _cn="${1}"
  _domains="${2}"
  _target_dir="${3}"

  certstrap request-cert \
    --passphrase "" \
    --common-name "${_cn}" \
    ${domains:+--domain "${_domains}"}
  certstrap sign \
    --CA "${CA_NAME}" \
    --passphrase "" \
    --years "2" \
    "${_cn}"

  mv "out/${_cn}.key" "${_target_dir}/"
  mv "out/${_cn}.csr" "${_target_dir}/"
  mv "out/${_cn}.crt" "${_target_dir}/"
}

rotate_cert() {
  _cn="${1}"
  _domains="${2}"
  _target_dir="${3}"

  mv "${_target_dir}/${_cn}.key" "${_target_dir}/${_cn}_old.key"
  mv "${_target_dir}/${_cn}.csr" "${_target_dir}/${_cn}_old.csr"
  mv "${_target_dir}/${_cn}.crt" "${_target_dir}/${_cn}_old.crt"

  generate_cert "${_cn}" "${_domains}" "${_target_dir}"
}

CERTS_DIR=$(cd "$1" && pwd)
CA_TARBALL="$2"
ACTION="${3:-}"
if [ "${ACTION}" != "create" ] && [ "${ACTION}" != "rotate" ]; then
  cat <<EOF
Usage:
  $0 <create|rotate>
EOF
  exit 1
fi

WORKING_DIR="$(mktemp -dt generate-cf-certs.XXXXXX)"
trap 'rm -rf "${WORKING_DIR}"' EXIT

mkdir "${WORKING_DIR}/out"
echo "Extracting ${CA_NAME} cert"
tar -xvzf "${CA_TARBALL}" -C "${WORKING_DIR}/out"

cd "${WORKING_DIR}"
for cert_entry in ${CERTS_TO_GENERATE}; do
  cn=${cert_entry%%,*}
  domains=${cert_entry#*,}

  if [ -f "${CERTS_DIR}/${cn}.crt" ]; then
    echo "Certificate ${cn} is already generated."
    if [ "${ACTION}" = "rotate" ]; then
      rotate_cert "${cn}" "${domains}" "${CERTS_DIR}"
    fi
  else
    echo "Creating certificate ${cn}..."
    generate_cert "${cn}" "${domains}" "${CERTS_DIR}"
  fi
done

