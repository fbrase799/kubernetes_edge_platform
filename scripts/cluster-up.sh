#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

if ! grep -q "name: ${CLUSTER_NAME}$" "${ROOT}/infra/cluster/k3d.yaml"; then
    echo "infra/cluster/k3d.yaml must name the cluster ${CLUSTER_NAME}" >&2
    exit 1
fi

docker info >/dev/null

mkdir -p "${ROOT}/.kube"
if cluster_exists; then
    echo "cluster ${CLUSTER_NAME} already exists"
else
    k3d cluster create --config "${ROOT}/infra/cluster/k3d.yaml"
fi

k3d kubeconfig get "${CLUSTER_NAME}" > "${KUBECONFIG}"
sed -i -E 's#https://(127\.0\.0\.1|0\.0\.0\.0|localhost):([0-9]+)#https://host.docker.internal:\2#g' "${KUBECONFIG}"
if ! grep -q "host.docker.internal" "${KUBECONFIG}"; then
    echo "kubeconfig server address was not rewritten for the toolchain container" >&2
    exit 1
fi
chmod 600 "${KUBECONFIG}"

kubectl wait --for=condition=Ready nodes --all --timeout=180s
kubectl get nodes
