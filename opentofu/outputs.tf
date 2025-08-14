output "infra_namespace" {
  value = kubernetes_namespace.infra.metadata[0].name
}

output "apps_namespace" {
  value = kubernetes_namespace.apps.metadata[0].name
}

output "jenkins_url_hint" {
  value = "Run: kubectl -n ${kubernetes_namespace.infra.metadata[0].name} port-forward svc/jenkins 8080:8080"
}

output "grafana_url_hint" {
  value = "Run: kubectl -n ${kubernetes_namespace.infra.metadata[0].name} port-forward svc/kube-prometheus-stack-grafana 3000:80"
}

output "registry_nodeport_hint" {
  value = "Registry: $(minikube ip):${var.registry_nodeport} (ensure containerd insecure hosts.toml)"
}
