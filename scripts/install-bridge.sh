#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

require_kubeconfig
helm upgrade --install telemetry-bridge "${ROOT}/deploy/helm/telemetry-bridge" \
    --namespace edge \
    --wait \
    --timeout 5m

found=""
for _ in $(seq 1 30); do
    query="$(kubectl -n edge exec influxdb-0 -- influx query \
        --host http://localhost:8086 \
        --org "${DEMO_ORG}" \
        --token "${DEMO_TOKEN}" \
        --raw \
        'from(bucket:"sensors") |> range(start:-15m) |> filter(fn:(r) => r._measurement == "sensor") |> limit(n:1)')"
    if grep -q "sensor" <<<"${query}"; then
        found="${query}"
        break
    fi
    sleep 2
done
if [[ -z "${found}" ]]; then
    echo "bridge did not write a sensor point" >&2
    kubectl -n edge logs deploy/telemetry-bridge --tail=50 || true
    exit 1
fi
echo "${found}"
