#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
script=platform/secrets/import.sh
[[ -f "$script" ]] || { echo 'FAIL: missing secret import'; exit 1; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export PATH="$tmp:$PATH" CALL_LOG="$tmp/calls" SECRET_INPUT="$tmp/input.json"
touch "$tmp/encrypted.sops.json"
cat > "$tmp/sops" <<'MOCK'
#!/usr/bin/env bash
cat "$SECRET_INPUT"
exit "${MOCK_SOPS_STATUS:-0}"
MOCK
cat > "$tmp/kubectl" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$CALL_LOG"
jq -e '.metadata.name == "postgis-bootstrap" and .data.password == "dGVzdA=="' >/dev/null
MOCK
chmod +x "$tmp/sops" "$tmp/kubectl"

run_import() {
  bash "$script" --context test-context --file "$tmp/encrypted.sops.json" "$@"
}

valid='{"apiVersion":"v1","kind":"Secret","metadata":{"name":"postgis-bootstrap","namespace":"gis"},"type":"Opaque","data":{"password":"dGVzdA=="}}'
printf '%s\n' "$valid" > "$SECRET_INPUT"
output=$(run_import)
[[ "$output" != *dGVzdA==* && ! -e "$CALL_LOG" ]]
if MOCK_SOPS_STATUS=1 run_import --apply >/dev/null 2>&1; then
  echo 'FAIL: accepted partial output from failed decryption'
  exit 1
fi
for filter in '.metadata.namespace = "default"' '.kind = "Deployment"' '.metadata.annotations = {"argocd.argoproj.io/tracking-id": "other"}' '.stringData = {"password": "example"}'; do
  jq "$filter" <<< "$valid" > "$SECRET_INPUT"
  if run_import --apply >/dev/null 2>&1; then
    echo "FAIL: accepted invalid secret with $filter"
    exit 1
  fi
done
test ! -e "$CALL_LOG"

printf '%s\n' "$valid" > "$SECRET_INPUT"
output=$(run_import --apply)
[[ "$output" != *dGVzdA==* ]]
test "$(cat "$CALL_LOG")" = '--context test-context --namespace gis apply --server-side --field-manager=gis-site-secrets -f -'
echo 'PASS: site secret import validates before writing and applies only to the specified context'
