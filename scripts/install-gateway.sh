#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

ensure_namespace
kubectl apply -f "${ROOT}/deploy/manifests/open-gateway.yaml"
kubectl -n edge rollout status deployment/open-gateway --timeout=180s

health_url="http://${HOST_GATEWAY}:8080/api/v1/health"
telemetry_url="http://${HOST_GATEWAY}:8080/api/v1/telemetry/current"
health=""
telemetry=""
for _ in $(seq 1 30); do
    if health="$(curl -fsS "${health_url}" 2>/dev/null)"; then
        telemetry="$(curl -fsS "${telemetry_url}" 2>/dev/null || true)"
        if grep -q '"value"' <<<"${telemetry}"; then
            break
        fi
    fi
    sleep 2
done
printf '%s\n' "${health}"
printf '%s\n' "${telemetry}"
if ! grep -q '"value"' <<<"${telemetry}"; then
    echo "gateway returned no readings" >&2
    exit 1
fi
