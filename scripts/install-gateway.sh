#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

ensure_namespace
kubectl apply -f "${ROOT}/deploy/manifests/open-gateway.yaml"
kubectl -n edge rollout status deployment/open-gateway --timeout=180s

health_url="http://${HOST_GATEWAY}:8080/api/v1/health"
telemetry_url="http://${HOST_GATEWAY}:8080/api/v1/telemetry/current"
for _ in $(seq 1 30); do
    if curl -fsS "${health_url}" >/dev/null 2>&1; then
        break
    fi
    sleep 2
done
curl -fsS "${health_url}"
echo
curl -fsS "${telemetry_url}"
echo
