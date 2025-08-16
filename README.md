# Infra Kata: Jenkins + OpenTofu + Helm + Minikube + Prometheus + Grafana

This repository provides a local, reproducible deployment system featuring:

- Local Kubernetes via Minikube
- Infrastructure namespace (CI + Observability): Jenkins, Prometheus, Grafana
- Application namespace for Java apps deployed via Helm
- OpenTofu (Terraform-compatible) for infra provisioning & Helm releases
- Jenkins Pipelines that fail on failing Java tests
- OpenTofu test coverage (native `tftest.hcl` tests)
- Automatic Prometheus metrics & Grafana dashboards exposure for all apps

## Container Image Registry (Minikube Addon + NodePort)
Enable the built-in addon first:
```
minikube addons enable registry
```
OpenTofu creates a NodePort (`registry-nodeport`) pointing at the addon so the node runtime can pull via plain HTTP using `<minikube-ip>:32000` (default).

Get IP & catalog:
```bash
MINIKUBE_IP=$(minikube ip)
REGISTRY=${MINIKUBE_IP}:32000
curl http://$REGISTRY/v2/_catalog || echo "(empty)"
```
Mark registry as insecure for containerd (if needed, after cluster start):
```bash
MINIKUBE_IP=$(minikube ip)
minikube ssh -- "sudo mkdir -p /etc/containerd/certs.d/${MINIKUBE_IP}:32000 && cat <<EOF | sudo tee /etc/containerd/certs.d/${MINIKUBE_IP}:32000/hosts.toml
server = \"http://${MINIKUBE_IP}:32000\"
[host.\"http://${MINIKUBE_IP}:32000\"]
  capabilities = [\"pull\", \"resolve\", \"push\"]
EOF
sudo systemctl restart containerd"
```
Recreate pods (or restart deployment) after enabling.

To mirror/push images manually (example):
```bash
curl http://${REGISTRY}/v2/_catalog
```

## Directory Structure
```
README.md
Jenkinsfile                  # Generic app pipeline
charts/
  app/                       # Helm chart template for Java apps
    Chart.yaml
    values.yaml
    templates/
      deployment.yaml
      service.yaml
      servicemonitor.yaml
  infra/                     # (Optional local override chart – most infra via OpenTofu Helm releases)
opentofu/
  providers.tf
  variables.tf
  main.tf
  namespaces.tf
  jenkins.tf
  monitoring.tf
  outputs.tf
  tests/
    namespaces.tftest.hcl
    jenkins.tftest.hcl
    monitoring.tftest.hcl
scripts/
  bootstrap.sh               # One-shot setup helper
sample-app/                  # Example Spring Boot app with Prometheus metrics
```

## Prerequisites
- macOS
- Homebrew
- Docker (for Minikube driver) or Hyperkit
- `minikube`, `kubectl`, `helm`, `opentofu` (`brew install minikube kubectl helm opentofu`)

## 1. Start Minikube
```bash
minikube start --cpus=4 --memory=8192 --kubernetes-version=stable \
  --insecure-registry=0.0.0.0/0   # (docker driver) allow plain HTTP registries for local demo
kubectl get nodes
```
If you already started Minikube without the flag and encounter image pull HTTPS errors, you can delete & restart, or add an insecure registry config (see Troubleshooting section below).

## 2. Provision Infra with OpenTofu
```bash
cd opentofu
tofu init
tofu plan -out=tf.plan
tofu apply tf.plan
```
This will create:
- Namespaces: `infra`, `apps`
- Helm releases:
  - Jenkins (in `infra`)
  - kube-prometheus-stack (Prometheus + Alertmanager + Grafana) (in `infra`)

## 3. Access Jenkins, Grafana & Prometheus (Ingress – no port-forward)
Enable the Minikube ingress controller once:
```bash
minikube addons enable ingress
```
Provision (or re-apply) infra so the Ingress object is created:
```bash
cd opentofu
tofu apply -auto-approve
```
Get IP & open URLs (nip.io auto-resolves hostnames to the IP):
```bash
MINIKUBE_IP=$(minikube ip)
echo "Jenkins:     http://jenkins.${MINIKUBE_IP}.nip.io"
echo "Grafana:     http://grafana.${MINIKUBE_IP}.nip.io"
echo "Prometheus:  http://prometheus.${MINIKUBE_IP}.nip.io"
```
Retrieve Jenkins admin password:
```bash
kubectl -n infra get secret jenkins -o jsonpath='{.data.jenkins-admin-password}' | base64 -d; echo
```
Grafana credentials (default unless overridden): `admin/prom-operator`.
Disable ingress if preferred by setting `enable_ingress = false` (then use port-forward or NodePorts).

## 4. Deploy an Example App (Manual Helm)
```bash
helm upgrade --install demo-app ./charts/app \
  -n apps \
  --set image.repository=docker.io/library/openjdk \
  --set image.tag=21-jdk \
  --set app.name=demo-app
```

## 5. Local Registry (NodePort) & Image Coordinates
The registry runs inside the cluster (infra namespace) and is exposed via NodePort `30050` (plain HTTP). We intentionally avoid the internal service DNS (`registry.infra.svc.cluster.local:5000`) because node-level image pulls may attempt HTTPS and fail. Instead, we resolve the Minikube node IP and use `MINIKUBE_IP:30050` everywhere (build + push + deploy image reference).

Discover IP & catalog:
```bash
MINIKUBE_IP=$(minikube ip)
REGISTRY=${MINIKUBE_IP}:30050
curl http://$REGISTRY/v2/_catalog || echo "Registry not yet reachable"
```

## 6. Jenkins Pipeline (Kaniko + Helm)
The `Jenkinsfile` stages:
1. Checkout
2. Resolve Registry Host (Node IP + NodePort or explicit override)
3. Mirror Base Image (Kaniko) into local registry (optional re-use layer cache behavior is Kaniko internal)
4. Build & Test (Maven unit tests)
5. Package & Dockerfile (creates Dockerfile using mirrored base image)
6. Build Image (Kaniko) -> push to local registry (plain HTTP)
7. Resolve Chart path
8. Verify Namespace (non-blocking RBAC check)
9. Deploy (Helm upgrade --install)

Key parameters:
- `APP_NAME` (default `sample-app`)
- `UPSTREAM_BASE_IMAGE` (public base to mirror, e.g. `docker.io/library/eclipse-temurin:21-jre`)
- `MIRRORED_BASE_IMAGE` (path under registry host, default `base/eclipse-temurin:21-jre`)
- `CHART_PATH` (relative path to Helm chart, default `charts/app`)
- `REGISTRY_NODEPORT` (default `30050`)
- `RESOLVE_MINIKUBE_IP` (bool, default true) – auto sets `REGISTRY_HOST` to `<node-ip>:<nodeport>`
- `REGISTRY_HOST_OVERRIDE` (optional full `host:port`; overrides auto resolution)

Resulting image reference deployed: `<resolved-registry-host>/<app-name>:latest`.

To run the pipeline, create a Multibranch or Pipeline job pointing at this repo (or copy `Jenkinsfile` into your app repo if using embedded chart). Adjust parameters as needed.

## 7. Observability
Each deployed app chart includes:
- Container port `http` plus `metrics` (configurable)
- `ServiceMonitor` for Prometheus if metrics enabled
- Fallback scrape annotations

Expose custom metrics in Java by adding Micrometer & Actuator and setting `management.server.port` to the metrics port (default 8081 in chart example).

## 8. OpenTofu Tests
```bash
cd opentofu
tofu test
```

## 9. Destroy
```bash
cd opentofu
tofu destroy -auto-approve
minikube delete
```

## Security Notes
- Local demo only: insecure registry, default admin credentials, no authN/Z hardening.
- Do not reuse in production without securing registry (TLS), RBAC, persistence, etc.

## Troubleshooting
### A. ImagePullBackOff / ErrImagePull (HTTPS attempted to HTTP registry)
Symptoms:
```
kubectl -n apps describe pod <pod>
# Events show attempts: ... pulling image "<ip>:30050/sample-app:latest" ... failed to do request: Head "https://<ip>:30050/v2/..."
```
Root cause: Node container runtime (Docker or containerd) attempts HTTPS because registry not marked as insecure.

Fix options:
1. (Recommended, recreate cluster) Start Minikube with a permissive insecure registry flag:
   ```bash
   minikube delete
   minikube start --cpus=4 --memory=8192 --kubernetes-version=stable --insecure-registry=0.0.0.0/0
   ```
2. (containerd runtime live patch) Mark registry as HTTP inside Minikube node:
   ```bash
   MINIKUBE_IP=$(minikube ip)
   minikube ssh -- "sudo mkdir -p /etc/containerd/certs.d/${MINIKUBE_IP}:30050 && \
cat <<EOF | sudo tee /etc/containerd/certs.d/${MINIKUBE_IP}:30050/hosts.toml
server = \"http://${MINIKUBE_IP}:30050\"
[host.\"http://${MINIKUBE_IP}:30050\"]
  capabilities = [\"pull\", \"resolve\", \"push\"]
EOF
sudo systemctl restart containerd"
   ```
   Then re-create failing pods:
   ```bash
   kubectl -n apps delete pod -l app.kubernetes.io/instance=<release-name>
   ```
3. Provide a registry add-on instead of custom one: `minikube addons enable registry` (uses cluster DNS `registry.kube-system.svc` and already configured) – then adapt Jenkins params to point to that service's NodePort or port-forward.

### B. Jenkins Build Cannot Reach Registry
- Verify registry service & endpoints:
  ```bash
  kubectl -n infra get svc registry -o wide
  kubectl -n infra get pods -l app=registry
  ```
- Ensure Resolve Registry Host stage in Jenkins log shows `Resolved registry host (NodeIP:NodePort)`.

### C. Registry Catalog Empty After Pipeline
- Check Kaniko logs for push errors (auth / mirror base). The pipeline uses `--insecure --insecure-pull`; ensure Node IP resolution happened before mirror stage.
- Query catalog:
  ```bash
  MINIKUBE_IP=$(minikube ip)
  curl http://${MINIKUBE_IP}:30050/v2/_catalog
  ```
  Expect: `{"repositories":["base/eclipse-temurin","sample-app"]}` (after at least one run).

### D. Update Deployed Image After Fix
If you corrected registry settings, just re-run pipeline. Helm upgrade will update Deployment which triggers new pull.

### E. Forcing Fresh Pull
```bash
kubectl -n apps rollout restart deployment/<release-name>
```

### F. Debugging Inside Node
```bash
minikube ssh -- curl -v http://$(minikube ip):30050/v2/_catalog
```
If this fails, the registry Pod or Service is not functioning.

## Next Steps / Enhancements
- Add caching layer or PVC for Kaniko cache
- Add integration tests stage
- Add progressive delivery (Argo Rollouts / Flagger)
- Add alert rules and sample Grafana dashboards for app metrics
- Replace insecure registry with local registry + self-signed TLS + trust injection

Enjoy hacking with this infra kata!
