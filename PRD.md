# Product Requirements Document (PRD)

## Kubernetes Edge Platform

**Project name:** Kubernetes Edge Platform  
**Repository:** `kubernetes_edge_plattform`  
**Status:** Proposed  
**Runtime:** Self-hosted multi-node k3s, provisioned with a k3d configuration file under Docker  
**Edge source:** C++ Open Gateway, consumed through its HTTP API

## 1. Objective

Build a small, reproducible platform that shows how a self-hosted Kubernetes cluster is provisioned and then used to run an edge gateway, store sensor measurements, and display them.

The platform must demonstrate:

1. Infrastructure as Code for the cluster environment, using a k3d configuration file.
2. A multi-node Kubernetes cluster.
3. Orchestration of the C++ Open Gateway, InfluxDB, and Grafana.
4. A path from the Open Gateway API to InfluxDB and then to Grafana.
5. The Open Gateway Qt display, running in the cluster and opened in a browser.
6. Application deployment with Kubernetes manifests and with Helm charts.
7. A configured Service and a working URL for Grafana, and a configured Service and URL for the Qt display.
8. InfluxDB measurements that survive a Pod restart.
9. Pod recovery, scaling, and a rolling update.

This is a hands-on infrastructure prototype. It is not a production edge product, a rewrite of Open Gateway, or a managed-cloud cluster.

## 2. Decisions

These choices are fixed so implementation does not reopen them.

| Topic | Decision |
| --- | --- |
| Kubernetes distribution | k3s, because it is self-hosted and suited to an edge platform |
| How the cluster is created | k3d, so every node is a container on the developer machine |
| Topology | 1 server node and 2 agent nodes |
| Infrastructure as Code | The committed k3d config at `infra/cluster/k3d.yaml`. `k3d cluster create --config` and `k3d cluster delete` are the only provision and destroy path. No OpenTofu, Terraform, or Ansible |
| Host toolchain | Docker only. `k3d`, `kubectl`, and Helm run in the toolchain image under `docker/` |
| Docker access | The toolchain container uses the host Docker socket. Cluster containers are siblings, not a nested Docker daemon |
| Open Gateway | Git submodule at `external/open-gateway`. The toolchain builds `docker/Dockerfile.gateway` and `docker/Dockerfile.display` from that tree |
| Gateway profile in the cluster | Cloud profile: temperature simulator on, admin listener off. No CAN hardware and no second dashboard |
| Gateway deployment | Kubernetes manifests |
| Qt display | Its own one-replica Deployment, `OGW_UI=novnc`. A Pod is not given the Mac’s X11 or Wayland session. The Qt process keeps `QT_QPA_PLATFORM=xcb` and draws on the X11 server the display image starts inside the Pod (Xvfb, 1280×720). noVNC publishes that window |
| InfluxDB | InfluxDB OSS 2.x from the upstream Helm chart, with a PersistentVolumeClaim |
| Grafana | Upstream Helm chart, NodePort published on the host by the k3d config |
| Sensor path into InfluxDB | A small bridge in this repository. It polls the gateway API and writes InfluxDB |
| Bridge deployment | Helm chart owned by this repository |
| Storage class | k3s local-path, which is already part of k3s |
| Ingress controller | Not required for the first version. Grafana is reached through a NodePort |
| Cluster monitoring stack | Not in the first version. Monitoring here means the Grafana dashboards of stored measurements, plus Kubernetes probes and rollout status |

Open Gateway keeps its own process history only. This platform does not modify the gateway to write to InfluxDB. The bridge is the integration.

The project brief names these "k3b configuration files". The file format that provisions this cluster is the k3d cluster config.

## 3. Target architecture

```text
Mac
└── Docker
    ├── toolchain container
    │     k3d, kubectl, Helm
    │
    └── k3d cluster (k3s)
          ├── server
          └── agent, agent
                │
                └── namespace: edge
                      ├── open-gateway          Deployment + Service   (manifests)
                      ├── open-gateway-display  Deployment + Service   (manifests)
                      ├── telemetry-bridge      Deployment             (Helm)
                      ├── influxdb              Stateful workload + PVC (upstream Helm)
                      └── grafana               Deployment + Service   (upstream Helm)
```

Data flow:

```text
temperature simulator
        │
        ▼
Open Gateway  GET /api/v1/telemetry/current
        │
        ├──► Qt display   http://127.0.0.1:6080/vnc.html
        │
        ▼
telemetry-bridge
        │
        ▼
InfluxDB  (PVC)
        │
        ▼
Grafana   http://127.0.0.1:30080
```

The gateway Service is ClusterIP. The display Pod and the bridge reach it by DNS inside the cluster. A localhost port for the gateway health endpoint is published only so the demo can show the API without using `kubectl port-forward` as the primary path. The display Service is a NodePort, published on the host as port 6080.

Steady state is one gateway Pod and one bridge Pod. Scaling the gateway is a demonstration of the Deployment, then the replica count returns to 1 so measurements are not written twice.

## 4. Scope

### 4.1 In scope

- Repeatable creation and deletion of the multi-node cluster from `infra/cluster/k3d.yaml`.
- Namespace `edge`.
- Open Gateway as a submodule, gateway and Qt display both built and deployed from this repository's toolchain.
- Bridge from the gateway's current-telemetry API to InfluxDB.
- InfluxDB with a persistent volume.
- Grafana with a provisioned InfluxDB datasource and one sensor dashboard.
- Documented drills for Pod recovery, scaling, rolling update, and volume survival.

### 4.2 Out of scope

- Managed Kubernetes (EKS, GKE, AKS, OpenShift).
- OpenTofu, Terraform, Pulumi, and Ansible for cluster or application setup.
- More than one control-plane node, external etcd, or a highly available control plane.
- Changing Open Gateway application code, its plugins, or the Qt display.
- A React client, or a second dashboard beside the Qt screen and Grafana.
- Attaching the display Pod to the developer machine’s XQuartz, WSLg, or Wayland socket. The Qt app has no Wayland mode. Desktop mode in Open Gateway expects a host X11 server, which a k3d Pod does not have.
- Real CAN or other physical sensors. The simulator is the sensor for this platform.
- GitOps, service mesh, operators, and a Prometheus stack.
- Authentication beyond the demo tokens stored as Kubernetes Secrets.
- Building or publishing a tagged Open Gateway release. Until that tag exists, the submodule pin is the integration.

## 5. Repository layout

```text
kubernetes_edge_plattform/
├── docker/                  toolchain image and compose file
├── infra/cluster/k3d.yaml   multi-node cluster spec
├── external/open-gateway/   git submodule
├── services/telemetry-bridge/
├── deploy/
│   ├── manifests/           namespace, gateway and display Deployments and Services
│   └── helm/telemetry-bridge/
├── scripts/                 cluster up/down and demo drills, run from the toolchain container
├── PRD.md
└── TASKS.md
```

Dockerfiles, Compose files, and other Docker build context stay under `docker/`. The gateway image builds from the submodule's `docker/Dockerfile.gateway`. The display image builds from the submodule's `docker/Dockerfile.display`.

## 6. Environment

### FR-01 — Toolchain container

A Docker image under `docker/` provides `k3d`, `kubectl`, Helm, and `git`. Compose mounts the repository and the host Docker socket into that container.

Nothing in the environment setup asks the developer to install k3s, k3d, kubectl, or Helm on the host. Docker is the host dependency.

**Acceptance:** From the toolchain container, `k3d version`, `kubectl version --client`, and `helm version` all print a version.

### FR-02 — Multi-node cluster as code

`infra/cluster/k3d.yaml` is the cluster. It defines one k3s server, two agents, the cluster name, and the published host ports. A script in `scripts/` runs `k3d cluster create --config infra/cluster/k3d.yaml` and writes the kubeconfig to a gitignored path. The matching destroy script runs `k3d cluster delete` for that cluster name. Creating an existing cluster does not create a second one.

Node counts, port maps, and k3s options live in the config file. The scripts do not pass those as extra flags.

Published host ports:

| Host | Cluster | Use |
| --- | --- | --- |
| `127.0.0.1:30080` | Grafana NodePort | Grafana UI |
| `127.0.0.1:8080` | Gateway | `GET /api/v1/health` and telemetry checks |
| `127.0.0.1:6080` | Display NodePort | Qt window through noVNC |

The gitignored kubeconfig is what `kubectl` and Helm use inside the toolchain container.

**Acceptance:** After create, `kubectl get nodes` shows 3 nodes Ready. `docker ps` shows the k3d server and both agents. Delete removes those containers. A second create on an empty machine recreates the same topology from the same file.

## 7. Applications

### FR-03 — Open Gateway submodule and manifests

`external/open-gateway` is a git submodule of the C++ Open Gateway. The first pin is commit `1e92a1a`. When a working release tag exists, the pin moves to that tag and the submodule remains the integration method only until that replacement is done. This repository does not vendor a copy of the gateway source.

The toolchain builds the gateway image from `external/open-gateway/docker/Dockerfile.gateway` and imports it into the k3d cluster. `deploy/manifests/` contains the namespace, a Deployment, a ClusterIP Service, readiness and liveness probes on `/api/v1/health`, and a resource request small enough for a laptop cluster. The admin listener stays off. The cloud profile file leaves simulators inactive. Each gateway Pod enables the temperature simulator through `PUT /api/v1/support/sources/temperature-sim` when the container starts, including after a restart, a scale-up, or a rolling update. `scripts/up.sh` creates the cluster and installs the whole stack.

**Acceptance:** `kubectl apply` of the manifests brings up a Ready gateway Pod. `curl` against `http://127.0.0.1:8080/api/v1/health` returns success, and `GET /api/v1/telemetry/current` returns the simulator reading.

### FR-11 — Qt display on the cluster’s own X11 session

Open Gateway’s local Compose requirement opens the Qt window on the developer machine’s X11 display (`OGW_UI=desktop`, XQuartz on a Mac or WSLg). That requirement does not fit this cluster. The display Pod cannot see that X11 socket, and the Qt app does not implement a Wayland session.

This platform therefore deploys the same display image with `OGW_UI=novnc`. That mode starts Xvfb at 1280×720, runs the Qt app against it with `QT_QPA_PLATFORM=xcb`, and serves the window through noVNC. This is the mode Open Gateway already uses when the UI is not attached to a desktop X server.

The toolchain builds `external/open-gateway/docker/Dockerfile.display` and imports that image. A second manifest deploys one replica. The container’s `OGW_API` is the gateway Service `http://open-gateway.edge.svc.cluster.local:8080`. The display does not link the gateway and does not load plugins. Restarting or deleting the display Pod leaves the gateway running.

The Service is a NodePort. k3d publishes it at `http://127.0.0.1:6080`. The page is `http://127.0.0.1:6080/vnc.html?autoconnect=1&resize=scale`. The display stays at one replica. Scaling drills apply to the gateway, not to this screen.

**Acceptance:** The display Pod is Ready. A browser opened at that noVNC URL shows the Qt window at 1280×720, talking to the gateway in the cluster. Deleting the display Pod does not remove the gateway Pod, and a new display Pod becomes Ready without reapplying the gateway manifest.

### FR-04 — InfluxDB

InfluxDB OSS 2.x is installed with its upstream Helm chart into namespace `edge`. A PersistentVolumeClaim holds the data. Organization, bucket, and token come from a Kubernetes Secret and Helm values committed in this repository. The token is a demo value, not a production secret, and the Secret manifest is safe to commit because the cluster exists only on the developer machine.

The InfluxDB Service is ClusterIP. Only the bridge and Grafana use it.

**Acceptance:** The InfluxDB Pod is Ready and bound to a PVC. The bucket exists and accepts a write.

### FR-05 — Telemetry bridge

`services/telemetry-bridge` is a small Python process, built into an image by the toolchain. On a fixed interval it calls `GET /api/v1/telemetry/current` on the gateway Service. Numeric readings are written to the InfluxDB bucket.

Each point uses:

| Item | Value |
| --- | --- |
| Measurement | `sensor` |
| Tags | device id, capability id |
| Field | `value` as a float |
| Time | the reading timestamp when the API provides one, otherwise the write time |

The bridge does not scrape Kubernetes, does not speak CAN, and does not embed gateway libraries. If the gateway is briefly unavailable, the bridge logs the error and retries on the next interval. It does not exit on a single failed poll.

The bridge is installed with the Helm chart in `deploy/helm/telemetry-bridge/`. The chart carries the image, the gateway URL, the InfluxDB URL, and the Secret reference.

**Acceptance:** With the gateway and InfluxDB Ready, installing the chart produces points in the `sensor` measurement without any manual `curl` into InfluxDB.

### FR-06 — Grafana

Grafana is installed with its upstream Helm chart into namespace `edge`. A Service of type NodePort is reachable at `http://127.0.0.1:30080`. The admin password is a committed demo value.

The chart provisioning configures:

- an InfluxDB datasource aimed at the in-cluster InfluxDB Service
- one dashboard that plots `sensor` values over time and shows the device and capability tags

No dashboard is clicked together by hand in the UI. A reinstall recreates the same datasource and dashboard.

**Acceptance:** A browser opened at `http://127.0.0.1:30080` shows Grafana, the datasource is healthy, and the dashboard shows the simulator series after the bridge has been running.

## 8. Operate and recover

These drills are scripts under `scripts/`, executed inside the toolchain container against the running cluster. The README records the commands and the expected outcome. The scripts are the demonstration, not a test framework.

### FR-07 — Measurements survive a Pod restart

Delete the InfluxDB Pod. The controller starts a new one on the same PVC. Points written before the delete are still queryable. The bridge writes new points after InfluxDB is Ready again.

**Acceptance:** A count or range query from before the delete still returns those points after the new Pod is Ready.

### FR-08 — Pod recovery

Delete the gateway Pod. The Deployment starts a replacement. Probes pass, and `GET /api/v1/telemetry/current` works again without reapplying the manifests.

**Acceptance:** `kubectl get pods` shows a new Ready gateway Pod, and the health URL succeeds.

### FR-09 — Scaling

Scale the gateway Deployment from 1 to 2 and show both Pods Ready and both addresses on the Service endpoints. Scale it back to 1 before leaving the demo. The bridge stays at 1 replica.

**Acceptance:** The scale-up shows 2 Ready gateway Pods. The scale-down leaves 1 Ready gateway Pod and the bridge still writing.

### FR-10 — Rolling update

Change a non-functional part of the gateway Pod template (a label or an environment value that does not alter the API) and roll the Deployment. `maxUnavailable` is 0 and `maxSurge` is 1. The rollout finishes with the new Pod Ready and the health URL succeeding.

**Acceptance:** `kubectl rollout status` reports success, and the running Pod uses the updated template.

## 9. What "done" means

The first version is done when all of the following are true on a machine that has Docker and this repository:

1. The toolchain container starts, and `k3d cluster create --config infra/cluster/k3d.yaml` creates a 3-node cluster.
2. Manifests deploy Open Gateway from the submodule, and the simulator is visible on the API.
3. Manifests deploy the Qt display with `OGW_UI=novnc`, and `http://127.0.0.1:6080/vnc.html?autoconnect=1&resize=scale` shows the 1280×720 window.
4. Helm installs InfluxDB, the telemetry bridge, and Grafana.
5. Grafana at `http://127.0.0.1:30080` shows the sensor series.
6. Deleting the InfluxDB Pod does not drop the earlier measurements.
7. The recovery, scale, and rollout scripts complete as written in FR-08, FR-09, and FR-10.
8. `k3d cluster delete` removes the cluster.

## 10. Temporary constraint

Until Open Gateway has a working tagged release, this platform includes it as the submodule `external/open-gateway` pinned to commit `1e92a1a`. The platform builds that tree. It does not copy the sources into this repository. Replacing the pin with a tag is a later change, not part of the first version.
