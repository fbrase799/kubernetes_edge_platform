#!/usr/bin/env bash
# FR-09: scale the gateway to 2 Ready Pods, then back to 1.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
require_kubeconfig

ready_count() {
    kubectl -n edge get pods -l app=open-gateway \
        -o jsonpath='{range .items[*]}{.status.conditions[?(@.type=="Ready")].status}{"\n"}{end}' \
        | grep -c '^True$' || true
}

endpoint_count() {
    kubectl -n edge get endpoints open-gateway \
        -o jsonpath='{range .subsets[*].addresses[*]}{.ip}{"\n"}{end}' \
        | grep -c . || true
}

kubectl -n edge scale deployment/open-gateway --replicas=2
for _ in $(seq 1 60); do
    if [[ "$(ready_count)" -eq 2 && "$(endpoint_count)" -eq 2 ]]; then
        break
    fi
    sleep 2
done
if [[ "$(ready_count)" -ne 2 || "$(endpoint_count)" -ne 2 ]]; then
    kubectl -n edge get pods -l app=open-gateway -o wide
    kubectl -n edge get endpoints open-gateway -o yaml
    echo "scale-up did not reach 2 ready pods and 2 endpoints" >&2
    exit 1
fi
echo "scaled to 2 ready gateway pods"

kubectl -n edge scale deployment/open-gateway --replicas=1
kubectl -n edge rollout status deployment/open-gateway --timeout=180s
for _ in $(seq 1 60); do
    pods="$(kubectl -n edge get pods -l app=open-gateway --no-headers | wc -l | tr -d ' ')"
    if [[ "${pods}" -eq 1 && "$(ready_count)" -eq 1 ]]; then
        break
    fi
    sleep 2
done
if [[ "$(ready_count)" -ne 1 ]]; then
    echo "scale-down did not leave 1 ready gateway pod" >&2
    exit 1
fi

bridge="$(kubectl -n edge get deploy telemetry-bridge -o jsonpath='{.status.readyReplicas}')"
if [[ "${bridge}" != "1" ]]; then
    echo "telemetry bridge ready replicas is ${bridge}, expected 1" >&2
    exit 1
fi
wrote=""
for _ in $(seq 1 20); do
    if kubectl -n edge logs deploy/telemetry-bridge --since=30s | grep -q "wrote "; then
        wrote="yes"
        break
    fi
    sleep 2
done
if [[ -z "${wrote}" ]]; then
    echo "bridge did not write after scale-down" >&2
    kubectl -n edge logs deploy/telemetry-bridge --tail=20 || true
    exit 1
fi
echo "scaled back to 1 gateway pod; bridge still writing"
