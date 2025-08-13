# Infra Kata: Jenkins + OpenTofu + Helm + Minikube + Prometheus + Grafana

This repository provides a local, reproducible deployment system featuring:

- Local Kubernetes via Minikube
- Infrastructure namespace (CI + Observability): Jenkins, Prometheus, Grafana
- Application namespace for Java apps deployed via Helm
- OpenTofu (Terraform-compatible) for infra provisioning & Helm releases
- Jenkins Pipelines that fail on failing Java tests
- OpenTofu test coverage (native `tftest.hcl` tests)
- Automatic Prometheus metrics & Grafana dashboards exposure for all apps

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
```

## Prerequisites
- macOS
- Homebrew
- Docker (for Minikube driver) or Hyperkit
- `minikube`, `kubectl`, `helm`, `opentofu` (`brew install minikube kubectl helm opentofu`)

## 1. Start Minikube
```bash
minikube start --cpus=4 --memory=8192 --kubernetes-version=stable
kubectl get nodes
```

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

## 3. Access Jenkins & Grafana
Forward services locally:
```bash
kubectl -n infra port-forward svc/jenkins 8080:8080 &
kubectl -n infra port-forward svc/kube-prometheus-stack-grafana 3000:80 &
```
Retrieve Jenkins admin password:
```bash
kubectl -n infra get secret jenkins -o jsonpath='{.data.jenkins-admin-password}' | base64 -d; echo
```
Grafana credentials (default unless overridden): `admin/prom-operator`.

## 4. Deploy an Example App
Update image reference & run:
```bash
helm upgrade --install demo-app ./charts/app \
  -n apps \
  --set image.repository=docker.io/library/openjdk \
  --set image.tag=21-jdk \
  --set app.name=demo-app
```

## 5. Jenkins Pipeline
Push a Java project (with `pom.xml` & tests) alongside this repo or configure a Multibranch Pipeline pointing at it. The `Jenkinsfile` stages:
1. Checkout
2. Build & Unit Test (fails build if tests fail)
3. Package Helm (optionally)
4. Deploy to `apps` namespace (helm upgrade --install)
5. Post: Archive test reports, mark build result

Environment variables / parameters:
- APP_NAME (default: repo name)
- IMAGE (pre-built image tag or built via Maven/ Jib)

## 6. Observability
Each deployed app chart includes:
- Container port `http` plus `metrics` (configurable)
- `Service` with `prometheus.io/scrape` labels for fallback discovery
- `ServiceMonitor` (works with kube-prometheus-stack) targeting metrics port

Expose custom metrics in Java by adding Micrometer & an endpoint:
```xml
<!-- pom.xml dependencies -->
<dependency>
  <groupId>io.micrometer</groupId>
  <artifactId>micrometer-registry-prometheus</artifactId>
</dependency>
<dependency>
  <groupId>org.springframework.boot</groupId>
  <artifactId>spring-boot-starter-actuator</artifactId>
</dependency>
```
Add to `application.properties`:
```
management.endpoints.web.exposure.include=prometheus,health,info
management.endpoint.prometheus.enabled=true
management.server.port=8081
```
Then set `metrics.port=8081` during Helm deploy.

## 7. OpenTofu Tests
Run native tests:
```bash
cd opentofu
tofu test
```
They assert presence & basic attributes of namespaces & Helm releases.

## 8. Destroy
```bash
cd opentofu
tofu destroy -auto-approve
minikube delete
```

## Security Notes
- This is a local demo; do not use default credentials in production.
- Add network policies & restrict RBAC for production usage.

## Troubleshooting
- If Jenkins persists Pending: ensure storage class is available (`minikube addons enable storage`).
- If Helm release fails: run `kubectl -n infra describe pod <pod>`.
- To view Prometheus targets: forward Prometheus service and open `/targets`.

## Next Steps / Enhancements
- Add dynamic app image build & push (using Jib) inside pipeline
- Add integration tests stage
- Add canary / progressive delivery (Argo Rollouts)
- Add SLO dashboards & alert rules

Enjoy hacking with this infra kata!
