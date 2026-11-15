#!/usr/bin/env bash
# FR-10: rolling update with maxUnavailable 0.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
require_kubeconfig

max_unavailable="$(kubectl -n edge get deploy open-gateway -o jsonpath='{.spec.strategy.rollingUpdate.maxUnavailable}')"
if [[ "${max_unavailable}" != "0" ]]; then
    echo "maxUnavailable is ${max_unavailable}, expected 0" >&2
    exit 1
fi

token="roll-$(date +%s)"
kubectl -n edge patch deployment open-gateway --type merge \
    -p "{\"spec\":{\"template\":{\"metadata\":{\"labels\":{\"edge.platform/rollout\":\"${token}\"}}}}}"
kubectl -n edge rollout status deployment/open-gateway --timeout=180s
got=""
for _ in $(seq 1 30); do
    got="$(kubectl -n edge get pods -l app=open-gateway -o go-template='{{range .items}}{{if not .metadata.deletionTimestamp}}{{index .metadata.labels "edge.platform/rollout"}}{{end}}{{end}}')"
    if [[ "${got}" == "${token}" ]]; then
        break
    fi
    sleep 2
done
if [[ "${got}" != "${token}" ]]; then
    echo "running pod label is ${got}, expected ${token}" >&2
    exit 1
fi
health_url="http://${HOST_GATEWAY}:8080/api/v1/health"
for _ in $(seq 1 30); do
    if curl -fsS "${health_url}" >/dev/null 2>&1; then
        echo "rollout ${token} finished and health succeeded"
        exit 0
    fi
    sleep 2
done
echo "health did not recover after rollout ${token}" >&2
exit 1
