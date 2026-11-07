#!/usr/bin/env bash
set -euo pipefail
if [[ $# -ne 1 || ! -d "$1" ]]; then
  echo 'Usage: validate.sh clusters/prod' >&2
  exit 2
fi
policy="$(dirname "$0")/policy.rb"
repo_root="$(cd "$(dirname "$0")/../.." && pwd -P)"
rendered=$(kubectl kustomize "$1")
ruby "$policy" <<< "$rendered"
paths=$(ruby -ryaml -e '
  STDIN.read.split(/^---\s*$/).each do |document|
    resource = YAML.safe_load(document)
    next unless resource && resource["kind"] == "Application"
    path = resource.dig("spec", "source", "path")
    abort "Expected a repository-local Application path" unless path.is_a?(String) &&
      path.match?(/\A(?:[A-Za-z0-9_-]+\/)*[A-Za-z0-9_-]+\z/)
    puts path
  end
' <<< "$rendered")
while IFS= read -r path; do
  [[ -n "$path" ]] || continue
  source=$(cd "$repo_root/$path" && pwd -P)
  [[ "$source" == "$repo_root/"* ]] || { echo "Application path leaves repository: $path" >&2; exit 1; }
  kubectl kustomize "$source" | ruby "$policy"
done <<< "$paths"
ruby "$policy" --root < "$1/bootstrap/root.yaml"
ruby "$policy" < "$1/bootstrap/project.yaml"
echo 'PASS: production GitOps root and local Applications render and pass local policy checks'
