resource "kubernetes_ingress_v1" "infra_ui" {
  count = var.enable_ingress ? 1 : 0

  metadata {
    name      = "infra-ui"
    namespace = kubernetes_namespace.infra.metadata[0].name
    annotations = {
      "kubernetes.io/ingress.class" = "nginx"
    }
  }

  spec {
    rule {
      host = local.jenkins_host
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = helm_release.jenkins.name
              port {
                number = 8080
              }
            }
          }
        }
      }
    }
    rule {
      host = local.grafana_host
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "kube-prometheus-stack-grafana"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
    rule {
      host = local.prometheus_host
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "kube-prometheus-stack-prometheus"
              port {
                number = 9090
              }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.jenkins, helm_release.kube_prometheus_stack]
}
