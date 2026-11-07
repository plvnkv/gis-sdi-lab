#!/usr/bin/env bash
set -euo pipefail
if [[ $# -ne 1 || ! -d "$1" ]]; then
  echo 'Usage: validate.sh clusters/prod' >&2
  exit 2
fi
policy="$(dirname "$0")/policy.rb"
kubectl kustomize "$1" | ruby "$policy"
ruby "$policy" --root < "$1/bootstrap/root.yaml"
ruby "$policy" < "$1/bootstrap/project.yaml"
echo 'PASS: production GitOps seed renders and passes local policy checks'
