#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

require_kubeconfig
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update grafana
helm upgrade --install grafana grafana/grafana \
    --namespace edge \
    --version "${GRAFANA_CHART_VERSION}" \
    --values "${ROOT}/deploy/helm/grafana/values.yaml" \
    --wait \
    --timeout 10m

base="http://${HOST_GATEWAY}:30080"
for _ in $(seq 1 30); do
    if curl -fsS "${base}/api/health" >/dev/null 2>&1; then
        break
    fi
    sleep 2
done
curl -fsS -u admin:edge-demo-password "${base}/api/health"
echo
health="$(curl -fsS -u admin:edge-demo-password "${base}/api/datasources/uid/influxdb/health")"
echo "${health}"
if ! grep -q '"status":"OK"' <<<"${health}"; then
    echo "Grafana InfluxDB datasource is not healthy" >&2
    exit 1
fi
curl -fsS -u admin:edge-demo-password "${base}/api/dashboards/uid/edge-sensors" >/dev/null
echo "Grafana dashboard edge-sensors is provisioned"
