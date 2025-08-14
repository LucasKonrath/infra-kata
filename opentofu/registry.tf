# Minikube registry addon must be enabled outside of OpenTofu:
#   minikube addons enable registry
# The addon already exposes a NodePort (commonly 32000 for HTTP). We discover it instead of creating another Service.
# Use: REGISTRY_HOST="$(minikube ip):<http-nodeport>" in Jenkins.

data "kubernetes_service" "addon_registry" {
  metadata {
    name      = "registry"
    namespace = "kube-system"
  }
}

locals {
  registry_http_nodeport = one([for p in data.kubernetes_service.addon_registry.spec[0].port : p.node_port if p.port == 80])
}

output "registry_http_nodeport" {
  description = "HTTP NodePort of Minikube addon registry"
  value       = local.registry_http_nodeport
}

output "registry_host_hint" {
  value = "Registry Host: $(minikube ip):${local.registry_http_nodeport} (mark insecure in containerd if needed)"
}

resource "kubernetes_service" "registry_direct" {
  metadata {
    name      = "registry-direct"
    namespace = "kube-system"
    labels = {
      app = "registry-direct"
      managed-by = "opentofu"
    }
  }
  spec {
    selector = {
      actual-registry = "true"
    }
    port {
      name        = "http"
      port        = 5000
      target_port = 5000
      node_port   = var.registry_direct_nodeport
      protocol    = "TCP"
    }
    type = "NodePort"
  }
}

output "registry_direct_nodeport" {
  value       = var.registry_direct_nodeport
  description = "NodePort for direct registry (port 5000)"
}
