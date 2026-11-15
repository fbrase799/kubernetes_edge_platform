#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

ensure_demo_secret
helm repo add influxdata https://helm.influxdata.com
helm repo update influxdata
helm upgrade --install influxdb influxdata/influxdb2 \
    --namespace edge \
    --version "${INFLUX_CHART_VERSION}" \
    --values "${ROOT}/deploy/helm/influxdb/values.yaml" \
    --wait \
    --timeout 10m

kubectl -n edge rollout status statefulset/influxdb --timeout=180s
phase="$(kubectl -n edge get pvc influxdb -o jsonpath='{.status.phase}')"
if [[ "${phase}" != "Bound" ]]; then
    echo "PVC influxdb is ${phase}, expected Bound" >&2
    exit 1
fi

kubectl -n edge exec influxdb-0 -- influx write \
    --host http://localhost:8086 \
    --org "${DEMO_ORG}" \
    --bucket "${DEMO_BUCKET}" \
    --token "${DEMO_TOKEN}" \
    "probe,device_id=write-check,capability_id=probe value=1"
query="$(kubectl -n edge exec influxdb-0 -- influx query \
    --host http://localhost:8086 \
    --org "${DEMO_ORG}" \
    --token "${DEMO_TOKEN}" \
    --raw \
    'from(bucket:"sensors") |> range(start:-15m) |> filter(fn:(r) => r._measurement == "probe") |> count()')"
echo "${query}"
if ! grep -q "probe" <<<"${query}"; then
    echo "InfluxDB did not return the probe write" >&2
    exit 1
fi
