resource "kubernetes_namespace" "infra" {
  metadata {
    name = var.jenkins_namespace
  }
}

resource "kubernetes_namespace" "apps" {
  metadata {
    name = var.apps_namespace
  }
}
