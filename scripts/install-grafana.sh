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
loki_health="$(curl -fsS -u admin:edge-demo-password "${base}/api/datasources/uid/loki/health")"
echo "${loki_health}"
if ! grep -q '"status":"OK"' <<<"${loki_health}"; then
    echo "Grafana Loki datasource is not healthy" >&2
    exit 1
fi
curl -fsS -u admin:edge-demo-password "${base}/api/dashboards/uid/edge-logs" >/dev/null
echo "Grafana dashboard edge-logs is provisioned"

loki_query() {
    curl -fsS -u admin:edge-demo-password -G \
        "${base}/api/datasources/proxy/uid/loki/loki/api/v1/query" \
        --data-urlencode "query=${1}"
}

pods_seen=""
for _ in $(seq 1 30); do
    pods_seen="$(loki_query 'sum by (pod) (count_over_time({namespace="edge"}[15m]))' || true)"
    if [[ "$(grep -o '"pod":' <<<"${pods_seen}" | wc -l | tr -d ' ')" -ge 2 ]]; then
        break
    fi
    sleep 2
done
echo "${pods_seen}"
if [[ "$(grep -o '"pod":' <<<"${pods_seen}" | wc -l | tr -d ' ')" -lt 2 ]]; then
    echo "Loki does not yet have lines from two workloads" >&2
    exit 1
fi

before="$(kubectl -n edge get pod -l app=open-gateway -o jsonpath='{.items[0].metadata.name}')"
kubectl -n edge delete pod "${before}" --wait=false
kept=""
for _ in $(seq 1 30); do
    if loki_query "sum by (pod) (count_over_time({namespace=\"edge\",pod=\"${before}\"}[15m]))" | grep -q "\"pod\":\"${before}\""; then
        kept="yes"
        break
    fi
    sleep 2
done
kubectl -n edge rollout status deployment/open-gateway --timeout=180s
if [[ -z "${kept}" ]]; then
    echo "logs from deleted gateway pod ${before} are missing" >&2
    exit 1
fi
echo "logs from deleted gateway pod ${before} are still queryable"
