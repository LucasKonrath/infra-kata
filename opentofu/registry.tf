# In-cluster, insecure local container registry for Kaniko/BuildKit pushes (dev only)
resource "kubernetes_deployment" "registry" {
  metadata {
    name      = "registry"
    namespace = kubernetes_namespace.infra.metadata[0].name
    labels = {
      app = "registry"
    }
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "registry"
      }
    }
    template {
      metadata {
        labels = {
          app = "registry"
        }
      }
      spec {
        container {
          name  = "registry"
          image = "registry:2"
          port {
            container_port = 5000
          }
          resources {
            limits = {
              cpu    = "200m"
              memory = "256Mi"
            }
            requests = {
              cpu    = "50m"
              memory = "64Mi"
            }
          }
        }
      }
    }
  }
  depends_on = [kubernetes_namespace.infra]
}

resource "kubernetes_service" "registry" {
  metadata {
    name      = "registry"
    namespace = kubernetes_namespace.infra.metadata[0].name
    labels = {
      app = "registry"
    }
  }
  spec {
    type = "NodePort"
    selector = {
      app = "registry"
    }
    port {
      name        = "http"
      port        = 5000
      target_port = 5000
      node_port   = 30050
    }
  }
}
