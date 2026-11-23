#!/usr/bin/env bash
# Create the cluster if needed, install the stack, and leave the temperature simulator on.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

"${ROOT}/scripts/cluster-up.sh"
"${ROOT}/scripts/build-gateway.sh"
"${ROOT}/scripts/install-gateway.sh"
"${ROOT}/scripts/build-display.sh"
"${ROOT}/scripts/install-display.sh"
"${ROOT}/scripts/install-influxdb.sh"
"${ROOT}/scripts/build-bridge.sh"
"${ROOT}/scripts/install-bridge.sh"
"${ROOT}/scripts/install-loki.sh"
"${ROOT}/scripts/install-alloy.sh"
"${ROOT}/scripts/install-grafana.sh"

echo "cluster ${CLUSTER_NAME} is in service"
echo "Qt display  http://127.0.0.1:6080/vnc.html?autoconnect=1&resize=scale"
echo "Grafana     http://127.0.0.1:30080  admin / edge-demo-password"
echo "gateway API http://127.0.0.1:8080/api/v1/telemetry/current"
