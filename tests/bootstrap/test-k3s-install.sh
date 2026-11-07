#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
script=bootstrap/k3s/install.sh
if [[ ! -f "$script" ]]; then
  echo "FAIL: missing installation entry point $script" >&2
  exit 1
fi
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir "$tmp/data"
printf '#!/bin/sh\nexit 99\n' > "$tmp/installer"
digest=$(shasum -a 256 "$tmp/installer" | cut -d ' ' -f 1)
if bash "$script" --config bootstrap/k3s/config.yaml --version v1.34.0+k3s1 \
  --installer "$tmp/installer" --sha256 "$digest" --mount "$tmp/data" >"$tmp/output" 2>&1; then
  echo 'FAIL: accepted an unmounted directory' >&2
  exit 1
fi
grep -Fq "Required filesystem is not mounted: $tmp/data" "$tmp/output"
echo 'PASS: k3s bootstrap rejects an unmounted data directory'
