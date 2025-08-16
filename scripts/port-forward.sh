#!/usr/bin/env bash
# Auto-start port-forwards for local access to Jenkins, Grafana, Prometheus
# Generated/managed by OpenTofu null_resource start_port_forwards

set -euo pipefail
NAMESPACE="infra"
APPS_NAMESPACE="apps"

# Optional: clean up any previous identical port-forward processes
if command -v pgrep >/dev/null 2>&1; then
  pgrep -fl "kubectl .*port-forward .* ${NAMESPACE} .*jenkins" >/dev/null 2>&1 && pkill -f "kubectl .*port-forward .* ${NAMESPACE} .*jenkins" || true
  pgrep -fl "kubectl .*port-forward .* ${NAMESPACE} .*kube-prometheus-stack-grafana" >/dev/null 2>&1 && pkill -f "kubectl .*port-forward .* ${NAMESPACE} .*kube-prometheus-stack-grafana" || true
  pgrep -fl "kubectl .*port-forward .* ${NAMESPACE} .*kube-prometheus-stack-prometheus" >/dev/null 2>&1 && pkill -f "kubectl .*port-forward .* ${NAMESPACE} .*kube-prometheus-stack-prometheus" || true
fi

pf() {
  local svc=$1; local lport=$2; local rport=$3; local ns=$4
  echo "Starting port-forward: ${svc} ${lport}->${rport} (ns=${ns})" >&2
  kubectl -n "${ns}" port-forward "svc/${svc}" "${lport}:${rport}" >/dev/null 2>&1 &
}

pf jenkins 8080 8080 "${NAMESPACE}"
pf kube-prometheus-stack-grafana 3000 80 "${NAMESPACE}"
pf kube-prometheus-stack-prometheus 9090 9090 "${NAMESPACE}"
# sample-app (two ports: 8080 app, 8081 metrics) map to local 9000/9001
pf sample-app 9000 8080 "${APPS_NAMESPACE}"
pf sample-app 9001 8081 "${APPS_NAMESPACE}"

sleep 1
cat <<EOF
Jenkins:    http://127.0.0.1:8080
Grafana:    http://127.0.0.1:3000
Prometheus: http://127.0.0.1:9090
Sample App: http://127.0.0.1:9000 (metrics: http://127.0.0.1:9001)
(Processes will terminate if your local shell session that launched Terraform ends; re-run: bash scripts/port-forward.sh)
EOF
