#!/usr/bin/env bash
set -euo pipefail

die() { printf '%s\n' "$*" >&2; exit 1; }

inventory=
system_id=
apply=false
while (( $# )); do
  case "$1" in
    --inventory) [[ $# -ge 2 ]] || die 'Missing inventory path'; inventory=$2; shift 2 ;;
    --system-id) [[ $# -ge 2 ]] || die 'Missing system ID'; system_id=$2; shift 2 ;;
    --apply) apply=true; shift ;;
    *) die "Unexpected argument: $1" ;;
  esac
done
[[ -f "$inventory" && "$system_id" =~ ^[a-z0-9]+$ ]] ||
  die 'Usage: deploy.sh --inventory FILE --system-id ID [--apply]'

expected_id=$(jq -er '.system_id | strings' "$inventory")
[[ "$system_id" == "$expected_id" ]] || die 'System ID does not match inventory'
profile=$(jq -er '.profile | strings | select(test("^[a-zA-Z0-9][a-zA-Z0-9_-]*$"))' "$inventory")
series=$(jq -er '.distro_series | strings | select(test("^[a-z][a-z0-9-]*$"))' "$inventory")
expected_disks=$(jq -ce '.disk_serials | arrays | select(length > 0 and all(.[]; type == "string" and length > 0) and (unique | length) == length) | sort' "$inventory")

machine=$(maas "$profile" machine read "$system_id")
jq -e --arg id "$system_id" '.system_id == $id and .status_name == "Allocated"' <<< "$machine" >/dev/null ||
  die 'Machine ID or Allocated status did not match'
actual_disks=$(maas "$profile" block-devices read "$system_id" |
  jq -ce '[.[] | select(.type == "physical") | .serial] | sort')
[[ "$actual_disks" == "$expected_disks" ]] || die 'Physical disks do not match inventory'

printf 'MAAS profile=%s system_id=%s Ubuntu=%s disks=%s\n' "$profile" "$system_id" "$series" "$actual_disks"
if "$apply"; then
  cloud_init="$(dirname "$0")/cloud-init.yaml"
  maas "$profile" machine deploy "$system_id" osystem=ubuntu "distro_series=$series" \
    "cloud_init_userdata=$(cat "$cloud_init")"
fi
