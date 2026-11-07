#!/usr/bin/env bash
set -euo pipefail

die() { printf '%s\n' "$*" >&2; exit 1; }

config=
version=
installer=
sha256=
mounts=()
while (( $# )); do
  [[ $# -ge 2 ]] || die "Missing value for $1"
  case "$1" in
    --config) config=$2 ;;
    --version) version=$2 ;;
    --installer) installer=$2 ;;
    --sha256) sha256=$2 ;;
    --mount) mounts+=("$2") ;;
    *) die "Unexpected argument: $1" ;;
  esac
  shift 2
done
[[ -f "$config" && -f "$installer" && "$version" =~ ^v[0-9]+\.[0-9]+\.[0-9]+\+k3s[0-9]+$ &&
   "$sha256" =~ ^[a-f0-9]{64}$ && ${#mounts[@]} -gt 0 ]] ||
  die 'Usage: install.sh --config FILE --version VERSION --installer FILE --sha256 HASH --mount PATH [--mount PATH ...]'

for path in "${mounts[@]}"; do
  [[ "$path" = /* && "$path" != / ]] || die "Invalid mount path: $path"
  mountpoint -q -- "$path" 2>/dev/null || die "Required filesystem is not mounted: $path"
done
[[ $EUID -eq 0 ]] || die 'Run as root on the GIS node'
actual_hash=$(sha256sum < "$installer")
[[ "${actual_hash%% *}" == "$sha256" ]] || die 'Installer checksum mismatch'

destination=/etc/rancher/k3s/config.yaml
if [[ -e "$destination" ]]; then
  cmp -s "$config" "$destination" || die 'Existing k3s configuration differs. Use the upgrade procedure.'
else
  install -d -m 0755 /etc/rancher/k3s
  install -m 0600 "$config" "$destination"
fi
if command -v k3s >/dev/null; then
  current=$(k3s --version | awk 'NR == 1 {print $3}')
  [[ "$current" == "$version" ]] || die 'Existing k3s version differs. Use the upgrade procedure.'
fi

mount_directive=
for path in "${mounts[@]}"; do
  [[ "$path" =~ ^/[a-zA-Z0-9_./-]+$ ]] || die "Unsupported mount path: $path"
  mount_directive+=" $path"
done
install -d -m 0755 /etc/systemd/system/k3s.service.d
drop_in=/etc/systemd/system/k3s.service.d/10-gis-mounts.conf
expected=$(printf '[Unit]\nRequiresMountsFor=%s\n' "$mount_directive")
if [[ -e "$drop_in" ]]; then
  [[ "$(cat "$drop_in")" == "$expected" ]] || die 'Existing required mount configuration differs'
else
  printf '%s\n' "$expected" > "$drop_in"
fi

if [[ ! -f /etc/systemd/system/k3s.service ]] || ! command -v k3s >/dev/null; then
  env -i PATH="$PATH" INSTALL_K3S_VERSION="$version" INSTALL_K3S_SKIP_START=true \
    sh "$installer" server
fi
systemctl daemon-reload
systemctl enable --now k3s.service
k3s kubectl wait --for=condition=Ready node --all --timeout=180s
