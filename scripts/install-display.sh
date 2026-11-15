#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

ensure_namespace
kubectl apply -f "${ROOT}/deploy/manifests/open-gateway-display.yaml"
kubectl -n edge rollout status deployment/open-gateway-display --timeout=180s

page="http://${HOST_GATEWAY}:6080/vnc.html?autoconnect=1&resize=scale"
for _ in $(seq 1 30); do
    if curl -fsS "http://${HOST_GATEWAY}:6080/vnc.html" >/dev/null 2>&1; then
        echo "display ready at ${page}"
        exit 0
    fi
    sleep 2
done
echo "noVNC page did not answer at ${page}" >&2
exit 1
