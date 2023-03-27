#!/bin/sh
set -eu

TMPDIR=${TMPDIR:-/tmp}
TF_DATA_DIR=$(mktemp -d "${TMPDIR}/terraform_lint.XXXXXX")
trap 'rm -r "${TF_DATA_DIR}"' EXIT

export TF_DATA_DIR

CWD=$(pwd)

for dir in terraform/*/; do
  cd "${dir}"
  terraform init >/dev/null
  terraform validate >/dev/null
  terraform fmt -check -diff
  cd "${CWD}"
done
