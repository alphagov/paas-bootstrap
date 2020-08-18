#!/bin/sh
set -eu

TMPDIR=${TMPDIR:-/tmp}
TF_DATA_DIR=$(mktemp -d "${TMPDIR}/terraform_lint.XXXXXX")
trap 'rm -r "${TF_DATA_DIR}"' EXIT

export TF_DATA_DIR

for dir in terraform/*/; do
  terraform init "${dir}" >/dev/null
  terraform validate "${dir}" >/dev/null
  terraform fmt -check -diff "${dir}"
done
