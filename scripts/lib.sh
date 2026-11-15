#!/usr/bin/env bash
# Shared paths for scripts that run inside the toolchain container.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export ROOT
export KUBECONFIG="${ROOT}/.kube/config"
export CLUSTER_NAME="edge"
export HOST_GATEWAY="${HOST_GATEWAY:-host.docker.internal}"
export DEMO_ORG="edge"
export DEMO_BUCKET="sensors"
export DEMO_TOKEN="edge-demo-token"
export INFLUX_CHART_VERSION="${INFLUX_CHART_VERSION:-2.1.2}"
export GRAFANA_CHART_VERSION="${GRAFANA_CHART_VERSION:-10.5.15}"

cluster_exists() {
    k3d cluster list | awk 'NR > 1 { print $1 }' | grep -qx "${CLUSTER_NAME}"
}

require_kubeconfig() {
    if [[ ! -f "${KUBECONFIG}" ]]; then
        echo "missing ${KUBECONFIG}; run scripts/cluster-up.sh first" >&2
        exit 1
    fi
}

ensure_namespace() {
    require_kubeconfig
    kubectl apply -f "${ROOT}/deploy/manifests/namespace.yaml"
}

ensure_demo_secret() {
    ensure_namespace
    kubectl apply -f "${ROOT}/deploy/manifests/edge-demo-secret.yaml"
}
