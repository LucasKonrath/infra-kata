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

output "ingress_hosts" {
  value = var.enable_ingress ? {
    jenkins    = local.jenkins_host
    grafana    = local.grafana_host
    prometheus = local.prometheus_host
  } : {}
}

output "ingress_url_hint" {
  value = var.enable_ingress ? "Open: http://jenkins.${local.ingress_domain_base} http://grafana.${local.ingress_domain_base} http://prometheus.${local.ingress_domain_base}" : "Ingress disabled"
}
