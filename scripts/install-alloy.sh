#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

require_kubeconfig
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update grafana
helm upgrade --install alloy grafana/alloy \
    --namespace edge \
    --version "${ALLOY_CHART_VERSION}" \
    --values "${ROOT}/deploy/helm/alloy/values.yaml" \
    --wait \
    --timeout 10m

kubectl -n edge rollout status daemonset/alloy --timeout=180s
ready="$(kubectl -n edge get daemonset alloy -o jsonpath='{.status.numberReady}')"
desired="$(kubectl -n edge get daemonset alloy -o jsonpath='{.status.desiredNumberScheduled}')"
if [[ "${ready}" -lt 1 || "${ready}" != "${desired}" ]]; then
    echo "Alloy ready ${ready}, desired ${desired}" >&2
    exit 1
fi
echo "Alloy is ready on ${ready} nodes"
