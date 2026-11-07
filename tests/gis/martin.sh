#!/usr/bin/env bash
set -euo pipefail
: "${MARTIN_URL:?Set the port-forwarded Martin base URL}"
url="${MARTIN_URL%/}"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
curl -fsS --max-time 10 "$url/health" >/dev/null
curl -fsS --max-time 10 "$url/catalog" | jq -e '.tiles | keys == ["pilot-points"]' >/dev/null
curl -fsS --max-time 10 -D "$tmp/headers" -o "$tmp/tile" "$url/pilot-points/0/0/0"
test -s "$tmp/tile"
grep -Eiq '^content-type: application/(vnd\.mapbox-vector-tile|x-protobuf)' "$tmp/headers"
status=$(curl -sS --max-time 10 -o /dev/null -w '%{http_code}' "$url/unlisted-source/0/0/0")
test "$status" = 404
echo 'PASS: Martin publishes the pilot MVT and rejects unknown sources'
