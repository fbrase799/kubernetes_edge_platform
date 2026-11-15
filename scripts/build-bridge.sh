#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

docker build \
    -f "${ROOT}/docker/Dockerfile.bridge" \
    -t edge-telemetry-bridge:local \
    "${ROOT}/services/telemetry-bridge"
k3d image import edge-telemetry-bridge:local -c "${CLUSTER_NAME}"
