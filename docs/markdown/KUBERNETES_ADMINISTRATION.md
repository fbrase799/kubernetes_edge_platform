# Kubernetes administration commands

These commands run inside the toolchain container. `KUBECONFIG` is `.kube/config`, and the cluster name is `edge`. `scripts/up.sh` and `scripts/cluster-down.sh` run the create, install, and delete sequence.

Open a shell in that container with:

```bash
docker compose -f docker/compose.yaml run --rm toolchain bash
```

## k3d

`infra/cluster/k3d.yaml` is the cluster. k3d reads it only on create.

```bash
k3d cluster create --config infra/cluster/k3d.yaml
k3d cluster list
k3d kubeconfig get edge
k3d cluster delete edge
```

Images built in the toolchain are imported into the cluster before the Pods can use them:

```bash
k3d image import edge-gateway:local -c edge
k3d image import edge-display:local -c edge
k3d image import edge-telemetry-bridge:local -c edge
```

## kubectl

The gateway and the Qt display are manifests. InfluxDB, Loki, Alloy, Grafana, and the telemetry bridge are Helm releases, and kubectl is how their rollout is checked.

```bash
kubectl apply -f deploy/manifests/namespace.yaml
kubectl apply -f deploy/manifests/edge-demo-secret.yaml
kubectl apply -f deploy/manifests/open-gateway.yaml
kubectl apply -f deploy/manifests/open-gateway-display.yaml

kubectl get nodes
kubectl wait --for=condition=Ready nodes --all --timeout=180s

kubectl -n edge get pods
kubectl -n edge get pvc
kubectl -n edge rollout status deployment/open-gateway --timeout=180s
kubectl -n edge rollout status deployment/open-gateway-display --timeout=180s
kubectl -n edge rollout status statefulset/influxdb --timeout=180s
kubectl -n edge rollout status statefulset/loki --timeout=180s
kubectl -n edge rollout status daemonset/alloy --timeout=180s

kubectl -n edge logs deploy/telemetry-bridge
kubectl -n edge scale deployment/open-gateway --replicas=2
kubectl -n edge scale deployment/open-gateway --replicas=1
kubectl -n edge delete pod -l app=open-gateway
```

## Helm

Each install is `helm upgrade --install`, so running it again updates the same release.

```bash
helm repo add influxdata https://helm.influxdata.com
helm repo update influxdata
helm upgrade --install influxdb influxdata/influxdb2 \
    --namespace edge \
    --version 2.1.2 \
    --values deploy/helm/influxdb/values.yaml \
    --wait \
    --timeout 10m

helm upgrade --install telemetry-bridge deploy/helm/telemetry-bridge \
    --namespace edge \
    --wait \
    --timeout 5m

helm repo add grafana https://grafana.github.io/helm-charts
helm repo update grafana
helm upgrade --install loki grafana/loki \
    --namespace edge \
    --version 6.55.0 \
    --values deploy/helm/loki/values.yaml \
    --wait \
    --timeout 10m

helm upgrade --install alloy grafana/alloy \
    --namespace edge \
    --version 1.16.0 \
    --values deploy/helm/alloy/values.yaml \
    --wait \
    --timeout 10m

helm upgrade --install grafana grafana/grafana \
    --namespace edge \
    --version 10.5.15 \
    --values deploy/helm/grafana/values.yaml \
    --wait \
    --timeout 10m
```
