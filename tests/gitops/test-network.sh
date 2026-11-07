#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
test -f platform/ingress/kustomization.yaml || { echo 'FAIL: GIS network manifests missing'; exit 1; }
kubectl kustomize platform/ingress | ruby -ryaml -e '
  docs = STDIN.read.split(/^---\s*$/).map { |doc| YAML.safe_load(doc) }.compact
  abort "missing protected GIS namespace" unless docs.any? { |doc|
    doc["kind"] == "Namespace" && doc.dig("metadata", "name") == "gis" &&
      doc.dig("metadata", "annotations", "argocd.argoproj.io/sync-options") == "Prune=false,Delete=false"
  }
  policies = docs.select { |doc| doc["kind"] == "NetworkPolicy" }
  abort "wrong policy namespace" unless policies.all? { |doc| doc.dig("metadata", "namespace") == "gis" }
  specs = policies.to_h { |doc| [doc.dig("metadata", "name"), doc["spec"]] }
  abort "missing default ingress isolation" unless specs["default-deny-ingress"] ==
    {"podSelector" => {}, "policyTypes" => ["Ingress"]}
  abort "same namespace ingress not allowed" unless specs.dig("allow-gis-ingress", "ingress") ==
    [{"from" => [{"podSelector" => {}}]}]
  expected_peer = {
    "namespaceSelector" => {"matchLabels" => {"kubernetes.io/metadata.name" => "kube-system"}},
    "podSelector" => {"matchLabels" => {"app.kubernetes.io/name" => "traefik"}}
  }
  traefik = specs.fetch("allow-traefik-ingress")
  abort "Traefik selector is too broad" unless traefik["podSelector"] ==
    {"matchLabels" => {"gis-sdi-lab/ingress" => "enabled"}}
  abort "Traefik peer or port is too broad" unless traefik["ingress"] ==
    [{"from" => [expected_peer], "ports" => [{"protocol" => "TCP", "port" => "gis-http"}]}]
'
echo 'PASS: GIS namespace protection and network policy contracts'
