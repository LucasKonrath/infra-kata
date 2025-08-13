run "plan" {
  command = plan

  assert {
    condition     = length(regexall("kubernetes_namespace.infra", run.stdout)) > 0
    error_message = "Infra namespace not planned"
  }

  assert {
    condition     = length(regexall("kubernetes_namespace.apps", run.stdout)) > 0
    error_message = "Apps namespace not planned"
  }
}
