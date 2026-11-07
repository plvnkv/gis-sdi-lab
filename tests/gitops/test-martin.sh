#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
[[ -f apps/martin/kustomization.yaml ]] || { echo 'FAIL: Martin manifests missing'; exit 1; }
kubectl kustomize apps/martin | ruby -ryaml -e '
  docs = STDIN.read.split(/^---\s*$/).map { |doc| YAML.safe_load(doc) }.compact
  by_kind = docs.to_h { |doc| [doc["kind"], doc] }
  service = by_kind.fetch("Service")
  abort "Martin must be internal" unless service.dig("spec", "type") == "ClusterIP" &&
    docs.none? { |doc| doc["kind"] == "Ingress" }
  container = by_kind.fetch("Deployment").dig("spec", "template", "spec", "containers").fetch(0)
  abort "Martin image must be pinned" unless container.fetch("image").match?(/@sha256:[a-f0-9]{64}\z/)
  env = container.fetch("env").find { |entry| entry["name"] == "MARTIN_DATABASE_URL" }
  abort "DSN must come from the reader Secret" unless env.dig("valueFrom", "secretKeyRef") ==
    {"name" => "martin-reader", "key" => "database-url"}
  config = YAML.safe_load(by_kind.fetch("ConfigMap").dig("data", "martin.yaml"))
  postgres = config.fetch("postgres")
  abort "Discovery or source list is unsafe" unless postgres["auto_publish"] == false &&
    postgres["connection_string"] == "\${MARTIN_DATABASE_URL}" &&
    postgres["tables"] == {"pilot-points" => {"schema" => "martin_pilot", "table" => "points", "srid" => 4326, "geometry_column" => "geom"}}
'
echo 'PASS: Martin uses the explicit internal pilot source'
