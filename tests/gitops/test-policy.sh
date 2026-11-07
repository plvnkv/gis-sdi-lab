#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
policy=tests/gitops/policy.rb
test -f "$policy" || { echo "FAIL: missing GitOps policy checker"; exit 1; }
printf 'apiVersion: v1\nkind: ConfigMap\nmetadata: {name: sample}\n' | ruby "$policy"
reject() {
  local output
  if output=$(printf '%s\n' "$2" | ruby "$policy" 2>&1); then
    echo "FAIL: accepted $1" >&2
    return 1
  fi
  grep -Fq "$1" <<< "$output" || { printf '%s\n' "$output" >&2; return 1; }
}
reject 'Secret is forbidden' 'kind: Secret
metadata: {name: sample}
stringData: {password: example}'
reject 'explicit immutable release tag or digest' 'kind: Deployment
metadata: {name: sample}
spec: {template: {spec: {containers: [{image: "registry.example/gis:latest"}]}}}'
reject 'Application outside GIS project' 'kind: Application
metadata: {name: sample, namespace: argocd}
spec: {project: default}'
reject 'PVC requires Prune=false and Delete=false' 'kind: PersistentVolumeClaim
metadata: {name: sample}'
echo 'PASS: GitOps policy fixtures'
