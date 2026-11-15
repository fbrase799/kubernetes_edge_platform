#!/usr/bin/env bash
# FR-07: measurements survive an InfluxDB Pod restart.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
require_kubeconfig

sensor_count() {
    kubectl -n edge exec influxdb-0 -- influx query \
        --host http://localhost:8086 \
        --org "${DEMO_ORG}" \
        --token "${DEMO_TOKEN}" \
        --raw \
        'from(bucket:"sensors") |> range(start:-6h) |> filter(fn:(r) => r._measurement == "sensor" and r._field == "value") |> group() |> count()'
}

csv_count() {
    printf '%s\n' "$1" | tr -d '\r' | awk -F, '/^,,/ { print $6; exit }'
}

before="$(sensor_count)"
echo "${before}"
before_n="$(csv_count "${before}")"
if [[ -z "${before_n}" || "${before_n}" -lt 1 ]]; then
    echo "expected sensor points before deleting the InfluxDB pod" >&2
    exit 1
fi
pvc_uid="$(kubectl -n edge get pvc influxdb -o jsonpath='{.metadata.uid}')"

kubectl -n edge delete pod influxdb-0 --wait=true
kubectl -n edge rollout status statefulset/influxdb --timeout=180s
after_uid="$(kubectl -n edge get pvc influxdb -o jsonpath='{.metadata.uid}')"
if [[ "${pvc_uid}" != "${after_uid}" ]]; then
    echo "PVC was replaced: ${pvc_uid} -> ${after_uid}" >&2
    exit 1
fi

after=""
after_n=""
for _ in $(seq 1 30); do
    if after="$(sensor_count)"; then
        after_n="$(csv_count "${after}")"
        if [[ -n "${after_n}" && "${after_n}" -ge "${before_n}" ]]; then
            break
        fi
    fi
    sleep 2
done
echo "${after}"
if [[ -z "${after_n}" || "${after_n}" -lt "${before_n}" ]]; then
    echo "sensor count dropped from ${before_n} to ${after_n:-0}" >&2
    exit 1
fi
echo "sensor points survived: ${before_n} before, ${after_n} after"
