#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 || "$1" != --root || ! -f "$2" || ! -f "$(dirname "$2")/project.yaml" ]]; then
  echo 'Usage: ARGOCD_INSTALL_MANIFEST=FILE ARGOCD_INSTALL_SHA256=HASH install.sh --root clusters/prod/bootstrap/root.yaml' >&2
  exit 2
fi
: "${ARGOCD_INSTALL_MANIFEST:?Specify the approved release manifest}"
: "${ARGOCD_INSTALL_SHA256:?Specify the approved SHA-256}"
actual=$(shasum -a 256 < "$ARGOCD_INSTALL_MANIFEST")
if [[ "${actual%% *}" != "$ARGOCD_INSTALL_SHA256" ]]; then
  echo 'Argo CD release manifest checksum mismatch' >&2
  exit 1
fi

kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply --server-side -n argocd -f "$ARGOCD_INSTALL_MANIFEST"
kubectl wait --for=condition=Established --timeout=120s \
  crd/applications.argoproj.io crd/appprojects.argoproj.io
kubectl apply -f "$(dirname "$2")/project.yaml"
kubectl apply -f "$2"
