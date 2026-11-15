# Kubernetes Edge Platform

Self-hosted multi-node k3s cluster for the C++ Open Gateway, InfluxDB, and Grafana. Docker is the only host dependency. `k3d`, `kubectl`, and Helm run in the toolchain container.

The cluster is `infra/cluster/k3d.yaml`: one server, two agents, Grafana on `127.0.0.1:30080`, the gateway API on `127.0.0.1:8080`, and the Qt window through noVNC on `127.0.0.1:6080`. Create and delete go through that file:

```bash
docker compose -f docker/compose.yaml build
docker compose -f docker/compose.yaml run --rm toolchain scripts/cluster-up.sh
docker compose -f docker/compose.yaml run --rm toolchain scripts/cluster-down.sh
```

`cluster-up.sh` is safe to run again. It does not create a second cluster.

## Demo credentials

These values are for the local cluster only.

| Item | Value |
| --- | --- |
| Qt display | `http://127.0.0.1:6080/vnc.html?autoconnect=1&resize=scale` |
| Grafana | `http://127.0.0.1:30080` |
| Grafana user / password | `admin` / `edge-demo-password` |
| InfluxDB organization | `edge` |
| InfluxDB bucket | `sensors` |
| InfluxDB token | `edge-demo-token` |

The dashboard is **Edge sensors** (`/d/edge-sensors`).

## Install

Open Gateway is the git submodule `external/open-gateway`, pinned to commit `1e92a1a` until a release tag exists. The submodule URL is the local Open Gateway checkout, because that repository has no published remote yet. The cluster runs the cloud profile: the temperature simulator is on, and the admin listener is off. The image's local profile turns that listener on, so the cloud profile is the one that matches this platform.

```bash
docker compose -f docker/compose.yaml run --rm toolchain scripts/build-gateway.sh
docker compose -f docker/compose.yaml run --rm toolchain scripts/install-gateway.sh
docker compose -f docker/compose.yaml run --rm toolchain scripts/build-display.sh
docker compose -f docker/compose.yaml run --rm toolchain scripts/install-display.sh
docker compose -f docker/compose.yaml run --rm toolchain scripts/install-influxdb.sh
docker compose -f docker/compose.yaml run --rm toolchain scripts/build-bridge.sh
docker compose -f docker/compose.yaml run --rm toolchain scripts/install-bridge.sh
docker compose -f docker/compose.yaml run --rm toolchain scripts/install-grafana.sh
```

From the host, `http://127.0.0.1:8080/api/v1/telemetry/current` is the simulator. Scripts inside the toolchain call the same published ports through `host.docker.internal`.

The gateway Deployment and Service are Kubernetes manifests. InfluxDB and Grafana are upstream Helm charts. The telemetry bridge chart in `deploy/helm/telemetry-bridge/` polls the gateway and writes the `sensor` measurement.

## Recovery drills

Run these after the install, still inside the toolchain container. Each script exits non-zero when the check fails.

```bash
docker compose -f docker/compose.yaml run --rm toolchain scripts/demo-influx-persistence.sh
docker compose -f docker/compose.yaml run --rm toolchain scripts/demo-pod-recovery.sh
docker compose -f docker/compose.yaml run --rm toolchain scripts/demo-scale.sh
docker compose -f docker/compose.yaml run --rm toolchain scripts/demo-rollout.sh
```

| Script | What it shows |
| --- | --- |
| `demo-influx-persistence.sh` | Deleting the InfluxDB pod keeps the same volume, and earlier `sensor` points are still queryable |
| `demo-pod-recovery.sh` | Deleting the gateway pod starts a new Ready pod, and the health URL works again |
| `demo-scale.sh` | The gateway scales to 2 Ready pods and 2 Service endpoints, then back to 1. The bridge stays at 1 replica and keeps writing |
| `demo-rollout.sh` | A pod-template label change rolls the gateway with `maxUnavailable: 0`, and the health URL still succeeds |

`scripts/cluster-down.sh` removes the cluster.
