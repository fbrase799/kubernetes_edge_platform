#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

if cluster_exists; then
    k3d cluster delete "${CLUSTER_NAME}"
else
    echo "cluster ${CLUSTER_NAME} is already absent"
fi
rm -f "${KUBECONFIG}"
