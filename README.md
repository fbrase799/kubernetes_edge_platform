# Kubernetes Edge Platform

A self-hosted Kubernetes cluster for provisioning, scaling, and administering an edge workload. Pods recover, scale, and roll out while measurements stay on their volume and logs stay queryable.

The workload is the C++ Open Gateway. It is integrated here, and its source code is not part of this repository. It supplies simulated sensors and one target sensor, motor control. InfluxDB stores the readings and Grafana displays them.

This repository defines that cluster in `infra/cluster/k3d.yaml`: one k3s server and two agents. Docker is the only host dependency. `k3d`, `kubectl`, and Helm run in the toolchain container.

## Quickstart

```bash
docker compose -f docker/compose.yaml build
docker compose -f docker/compose.yaml run --rm toolchain scripts/up.sh
# remove the cluster
docker compose -f docker/compose.yaml run --rm toolchain scripts/cluster-down.sh
```

`scripts/up.sh` creates the cluster, builds the images, and installs the gateway, the Qt display, InfluxDB, the telemetry bridge, Loki, Alloy, and Grafana. It waits until the temperature simulator is publishing. Running it again reuses the existing cluster. `scripts/cluster-down.sh` removes it. The [Kubernetes administration commands](docs/markdown/KUBERNETES_ADMINISTRATION.md) are the `k3d`, `kubectl`, and Helm commands those scripts run.

| Service | URL |
| --- | --- |
| Grafana | [http://127.0.0.1:30080](http://127.0.0.1:30080) |
| Gateway API | [http://127.0.0.1:8080](http://127.0.0.1:8080) |
| Current telemetry | [http://127.0.0.1:8080/api/v1/telemetry/current](http://127.0.0.1:8080/api/v1/telemetry/current) |
| Qt display | [http://127.0.0.1:6080/vnc.html?autoconnect=1&resize=scale](http://127.0.0.1:6080/vnc.html?autoconnect=1&resize=scale) |

Logins and the InfluxDB organization, bucket, and token are in [Demo credentials](docs/markdown/DEMO_CREDENTIALS.md).

Open Gateway is the git submodule `external/open-gateway`, pinned to commit `1e92a1a` until a release tag exists. The cluster runs the cloud profile: the temperature simulator is on and the admin listener is off. Each gateway Pod turns the simulator on when it starts, including after a restart, a scale-up, or a rolling update. Scripts inside the toolchain call these ports through `host.docker.internal`.

## Scenarios

Grafana is already showing the sensor series and the cluster logs after Quickstart. The scripts below exercise persistence, recovery, scaling, and a rolling update. Run them inside the toolchain container. Each exits non-zero when the check fails.

The sensor dashboard is **Edge sensors** (`/d/edge-sensors`). The telemetry bridge polls the gateway and writes the `sensor` measurement.

The log dashboard is **Edge logs** (`/d/edge-logs`). It opens on the `edge` namespace. The Workload filter uses the stable name (`open-gateway`, `telemetry-bridge`, `influxdb`, `grafana`, `open-gateway-display`), and the row shows the log line. Loki and Alloy stay in a collapsed section at the bottom. Lines remain after the Pod that wrote them is replaced.

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

## Tech stack

- **k3s and k3d** — multi-node cluster as code in `infra/cluster/k3d.yaml` (one server, two agents)
- **Docker** — the host dependency; the toolchain image under `docker/` runs `k3d`, `kubectl`, and Helm
- **C++ Open Gateway** — integrated edge service; its source is the `external/open-gateway` submodule, deployed with Kubernetes manifests
- **Qt display** — one-replica Deployment, window served through noVNC
- **Telemetry bridge** — Python service in `services/telemetry-bridge/`, installed with the Helm chart in `deploy/helm/telemetry-bridge/`
- **InfluxDB OSS 2.x** — upstream Helm chart, data on a PersistentVolumeClaim (k3s local-path)
- **Grafana** — upstream Helm chart, NodePort on the host, provisioned InfluxDB datasource and dashboards
- **Grafana Loki and Grafana Alloy** — Loki stores container logs; Alloy ships stdout and stderr from every container

The gateway Deployment and Service are Kubernetes manifests. InfluxDB, Loki, Alloy, and Grafana are upstream Helm charts.

## Resources

- [Architecture](docs/markdown/ARCHITECTURE.md) — cluster topology, workloads, and the path from the gateway to InfluxDB, Loki, and Grafana
- [Product requirements](PRD.md) — scope, decisions, and acceptance criteria
