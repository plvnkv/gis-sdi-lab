#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export PATH="$tmp:$PATH" DEPLOY_LOG="$tmp/log"
cat > "$tmp/maas" <<'MOCK'
#!/usr/bin/env bash
case "$2 $3" in
  'machine read') printf '{"system_id":"gis001","status_name":"%s"}\n' "${MACHINE_STATUS:-Allocated}" ;;
  'block-devices read') printf '[{"type":"physical","serial":"%s"}]\n' "${DISK_SERIAL:-test-serial}" ;;
  'machine deploy') printf '%s %s %s %s %s %s %s\n' "$1" "$2" "$3" "$4" "$5" "$6" "${7%%=*}" >> "$DEPLOY_LOG" ;;
  *) exit 2 ;;
esac
MOCK
chmod +x "$tmp/maas"
cat > "$tmp/inventory.json" <<'JSON'
{"profile":"test","system_id":"gis001","disk_serials":["test-serial"],"distro_series":"noble"}
JSON
script=bootstrap/maas/deploy.sh
if [[ ! -f "$script" ]]; then
  echo "FAIL: missing deployment entry point $script" >&2
  exit 1
fi
deploy() { bash "$script" --inventory "$tmp/inventory.json" --system-id "$@"; }
reject() {
  if deploy "$@" >/dev/null 2>&1; then
    echo "FAIL: unsafe deployment accepted" >&2
    exit 1
  fi
  test ! -e "$DEPLOY_LOG"
}
reject wrong-id --apply
DISK_SERIAL=other reject gis001 --apply
MACHINE_STATUS=Deployed reject gis001 --apply
deploy gis001 >/dev/null
test ! -e "$DEPLOY_LOG"
deploy gis001 --apply >/dev/null
test "$(wc -l < "$DEPLOY_LOG" | tr -d ' ')" = 1
grep -q '^test machine deploy gis001 osystem=ubuntu distro_series=noble ' "$DEPLOY_LOG"
echo 'PASS: deploy rejects unsafe targets, previews by default, and applies an allocated matching target'
