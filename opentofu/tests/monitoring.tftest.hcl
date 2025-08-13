run "plan" {
  command = plan

  assert {
    condition     = length(regexall("helm_release.kube_prometheus_stack", run.stdout)) > 0
    error_message = "Monitoring stack release not planned"
  }
}
