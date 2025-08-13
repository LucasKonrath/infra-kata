#!/usr/bin/env bash
set -euo pipefail

# Bootstrap script for local infra kata

echo "Starting Minikube..."
minikube status >/dev/null 2>&1 || minikube start --cpus=4 --memory=8192 --kubernetes-version=stable

echo "Applying OpenTofu configuration..."
(cd opentofu && tofu init && tofu apply -auto-approve)

echo "Port-forwarding Jenkins (8080) & Grafana (3000) in background..."
(kubectl -n infra port-forward svc/jenkins 8080:8080 >/dev/null 2>&1 &)
(kubectl -n infra port-forward svc/kube-prometheus-stack-grafana 3000:80 >/dev/null 2>&1 &)

echo "Jenkins admin password:"
kubectl -n infra get secret jenkins -o jsonpath='{.data.jenkins-admin-password}' | base64 -d; echo

echo "Done. Visit Jenkins: http://localhost:8080  Grafana: http://localhost:3000"
