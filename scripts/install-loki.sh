#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

ensure_namespace
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update grafana
helm upgrade --install loki grafana/loki \
    --namespace edge \
    --version "${LOKI_CHART_VERSION}" \
    --values "${ROOT}/deploy/helm/loki/values.yaml" \
    --wait \
    --timeout 10m

kubectl -n edge rollout status statefulset/loki --timeout=180s
phase="$(kubectl -n edge get pvc storage-loki-0 -o jsonpath='{.status.phase}' 2>/dev/null || true)"
if [[ -z "${phase}" ]]; then
    phase="$(kubectl -n edge get pvc -l app.kubernetes.io/name=loki -o jsonpath='{.items[0].status.phase}')"
fi
if [[ "${phase}" != "Bound" ]]; then
    kubectl -n edge get pvc
    echo "Loki PVC is ${phase}, expected Bound" >&2
    exit 1
fi
echo "Loki is ready"
