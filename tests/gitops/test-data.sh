#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."

check() {
  local app=$1 service=$2 secret=$3
  [[ -f "apps/$app/kustomization.yaml" ]] || { echo "FAIL: $app manifests missing"; return 1; }
  kubectl kustomize "apps/$app" | ruby -ryaml -e '
    app, service, secret = ARGV
    resources = STDIN.read.split(/^---\s*$/).map { |doc| YAML.safe_load(doc) }.compact
    by_kind = resources.to_h { |resource| [resource["kind"], resource] }
    abort "Unexpected namespace" unless resources.all? { |resource| resource.dig("metadata", "namespace") == "gis" }
    deployment = by_kind.fetch("Deployment")
    abort "Unsafe rollout" unless deployment.dig("spec", "replicas") == 1 && deployment.dig("spec", "strategy", "type") == "Recreate"
    pod = deployment.dig("spec", "template", "spec")
    container = pod.fetch("containers").fetch(0)
    abort "Image must be digest-pinned" unless container.fetch("image").match?(/@sha256:[0-9a-f]{64}\z/)
    abort "Missing required credentials" unless container.fetch("env").any? { |entry|
      entry.dig("valueFrom", "secretKeyRef", "name") == secret && !entry.dig("valueFrom", "secretKeyRef", "optional")
    }
    abort "Wrong PVC" unless pod.fetch("volumes").any? { |volume| volume.dig("persistentVolumeClaim", "claimName") == "#{app}-data" }
    claim = by_kind.fetch("PersistentVolumeClaim")
    abort "Unsafe PVC" unless claim.dig("metadata", "name") == "#{app}-data" && claim.dig("spec", "storageClassName") == "gis-local"
    endpoint = by_kind.fetch("Service")
    abort "Unexpected service exposure" unless endpoint.dig("metadata", "name") == service && endpoint.dig("spec", "type") == "ClusterIP"
  ' "$app" "$service" "$secret"
}
check postgis postgis-rw postgis-bootstrap
check rustfs rustfs rustfs-bootstrap
echo 'PASS: GIS data workload contracts'
