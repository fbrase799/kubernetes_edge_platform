#!/usr/bin/env bash
# FR-08: deleting the gateway Pod brings a new Ready Pod back.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
require_kubeconfig

before="$(kubectl -n edge get pod -l app=open-gateway -o jsonpath='{.items[0].metadata.name}')"
kubectl -n edge delete pod "${before}" --wait=true
kubectl -n edge rollout status deployment/open-gateway --timeout=180s
after="$(kubectl -n edge get pod -l app=open-gateway -o jsonpath='{.items[0].metadata.name}')"
if [[ "${before}" == "${after}" ]]; then
    echo "gateway pod name did not change" >&2
    exit 1
fi
kubectl -n edge wait --for=condition=Ready "pod/${after}" --timeout=180s

health_url="http://${HOST_GATEWAY}:8080/api/v1/health"
telemetry_url="http://${HOST_GATEWAY}:8080/api/v1/telemetry/current"
for _ in $(seq 1 30); do
    if curl -fsS "${health_url}" >/dev/null 2>&1; then
        break
    fi
    sleep 2
done
curl -fsS "${health_url}" >/dev/null
curl -fsS "${telemetry_url}" >/dev/null
echo "gateway recovered: ${before} -> ${after}"
