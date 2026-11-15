#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

if [[ ! -f "${ROOT}/external/open-gateway/docker/Dockerfile.gateway" ]]; then
    echo "missing Open Gateway submodule at external/open-gateway" >&2
    exit 1
fi

docker build \
    -f "${ROOT}/external/open-gateway/docker/Dockerfile.gateway" \
    --build-arg OGW_WITH_CAN=0 \
    -t edge-gateway:local \
    "${ROOT}/external/open-gateway"
k3d image import edge-gateway:local -c "${CLUSTER_NAME}"
