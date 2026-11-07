#!/usr/bin/env bash
set +x
set -euo pipefail

die() { printf '%s\n' "$*" >&2; exit 1; }

context=
file=
apply=false
while (( $# )); do
  case "$1" in
    --context) [[ $# -ge 2 ]] || die 'Missing Kubernetes context'; context=$2; shift 2 ;;
    --file) [[ $# -ge 2 ]] || die 'Missing SOPS file'; file=$2; shift 2 ;;
    --apply) apply=true; shift ;;
    *) die 'Unexpected argument' ;;
  esac
done
[[ -n "$context" && -f "$file" ]] ||
  die 'Usage: import.sh --context CONTEXT --file FILE.sops.json [--apply]'

if ! secret=$(sops decrypt --input-type json --output-type json /dev/stdin < "$file" 2>/dev/null); then
  die 'SOPS decryption failed. Check the encrypted JSON file and age identity.'
fi
if ! name=$(jq -ers '
  select(length == 1) | .[0]
  | select(keys == ["apiVersion", "data", "kind", "metadata", "type"])
  | select(.apiVersion == "v1" and .kind == "Secret" and .type == "Opaque")
  | select((.metadata | keys) == ["name", "namespace"] and .metadata.namespace == "gis")
  | select(.data | type == "object" and length > 0 and all(to_entries[];
      (.key | test("^[a-zA-Z0-9._-]+$")) and
      (.value | type == "string" and length > 0 and
        test("^(?:[a-zA-Z0-9+/]{4})*(?:[a-zA-Z0-9+/]{2}==|[a-zA-Z0-9+/]{3}=)?$"))))
  | .metadata.name
  | select(type == "string" and length <= 253 and
      test("^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)*$"))
' <<< "$secret" 2>/dev/null); then
  die 'Expected one v1 Opaque Secret with base64 data and only name/namespace metadata in gis.'
fi

if "$apply"; then
  if ! kubectl --context "$context" --namespace gis apply --server-side \
    --field-manager=gis-site-secrets -f - <<< "$secret" >/dev/null 2>&1; then
    die 'Kubernetes rejected the Secret. Check the context, namespace, permissions and field ownership.'
  fi
  printf 'Applied gis/%s to context %s\n' "$name" "$context"
else
  printf 'Validated gis/%s for context %s\n' "$name" "$context"
fi
