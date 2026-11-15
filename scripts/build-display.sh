#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

if [[ ! -f "${ROOT}/external/open-gateway/docker/Dockerfile.display" ]]; then
    echo "missing Open Gateway display image definition" >&2
    exit 1
fi

docker build \
    -f "${ROOT}/external/open-gateway/docker/Dockerfile.display" \
    -t edge-display:local \
    "${ROOT}/external/open-gateway"
k3d image import edge-display:local -c "${CLUSTER_NAME}"
