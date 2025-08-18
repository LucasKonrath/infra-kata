run "plan" {
  command = plan
  assert {
    condition     = kubernetes_namespace.infra.metadata[0].name == var.jenkins_namespace
    error_message = "Infra namespace name mismatch"
  }
  assert {
    condition     = kubernetes_namespace.apps.metadata[0].name == var.apps_namespace
    error_message = "Apps namespace name mismatch"
  }
}
