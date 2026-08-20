#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

CHART="${CHART:-${REPO_ROOT}/helm/tenant-platform}"
KUBECONFIG_PATH="${KUBECONFIG_PATH:-/etc/rancher/k3s/k3s.yaml}"
PSA_VERSION="${PSA_VERSION:-v1.36}"

usage() {
  echo "Usage:"
  echo "  $0 create <tenant-name> <hostname>"
  echo "  $0 suspend <tenant-name>"
  echo "  $0 resume <tenant-name>"
  echo "  $0 delete <tenant-name>"
  exit 1
}

create_tenant() {
  TENANT="$1"
  HOSTNAME="$2"

  echo "[1/4] Creating namespace: $TENANT"
  sudo kubectl create namespace "$TENANT" \
    --kubeconfig "$KUBECONFIG_PATH"

  echo "[2/4] Applying tenant and Pod Security labels"
  sudo kubectl label namespace "$TENANT" \
    "tenant=$TENANT" \
    "pod-security.kubernetes.io/enforce=restricted" \
    "pod-security.kubernetes.io/enforce-version=$PSA_VERSION" \
    "pod-security.kubernetes.io/warn=restricted" \
    "pod-security.kubernetes.io/warn-version=$PSA_VERSION" \
    "pod-security.kubernetes.io/audit=restricted" \
    "pod-security.kubernetes.io/audit-version=$PSA_VERSION" \
    --overwrite \
    --kubeconfig "$KUBECONFIG_PATH"

  echo "[3/4] Installing tenant platform with Helm"
  sudo helm install "$TENANT" "$CHART" \
    -n "$TENANT" \
    --set "tenant.name=$TENANT" \
    --set "tenant.hostname=$HOSTNAME" \
    --wait \
    --timeout 5m \
    --kubeconfig "$KUBECONFIG_PATH"

  echo "[4/4] Tenant provisioned successfully"
  echo "Tenant:   $TENANT"
  echo "Hostname: https://$HOSTNAME"
}

suspend_tenant() {
  TENANT="$1"

  echo "[1/2] Suspending tenant: $TENANT"

  sudo helm upgrade "$TENANT" "$CHART" \
    -n "$TENANT" \
    --reuse-values \
    --set replicaCount=0 \
    --wait \
    --timeout 5m \
    --kubeconfig "$KUBECONFIG_PATH"

  echo "[2/2] Tenant suspended successfully"
  echo "Tenant: $TENANT"
}

resume_tenant() {
  TENANT="$1"

  echo "[1/2] Resuming tenant: $TENANT"

  sudo helm upgrade "$TENANT" "$CHART" \
    -n "$TENANT" \
    --reuse-values \
    --set replicaCount=1 \
    --wait \
    --timeout 5m \
    --kubeconfig "$KUBECONFIG_PATH"

  echo "[2/2] Tenant resumed successfully"
  echo "Tenant: $TENANT"
}

delete_tenant() {
  TENANT="$1"

  echo "[1/3] Removing Helm release: $TENANT"

  sudo helm uninstall "$TENANT" \
    -n "$TENANT" \
    --wait \
    --timeout 5m \
    --kubeconfig "$KUBECONFIG_PATH"

  echo "[2/3] Deleting namespace: $TENANT"

  sudo kubectl delete namespace "$TENANT" \
    --kubeconfig "$KUBECONFIG_PATH"

  echo "[3/3] Tenant deleted successfully"
  echo "Tenant: $TENANT"
}

if [[ $# -lt 1 ]]; then
  usage
fi

case "$1" in
  create)
    [[ $# -eq 3 ]] || usage
    create_tenant "$2" "$3"
    ;;
  suspend)
    [[ $# -eq 2 ]] || usage
    suspend_tenant "$2"
    ;;
  resume)
    [[ $# -eq 2 ]] || usage
    resume_tenant "$2"
    ;;
  delete)
    [[ $# -eq 2 ]] || usage
    delete_tenant "$2"
    ;;
  *)
    usage
    ;;
esac
