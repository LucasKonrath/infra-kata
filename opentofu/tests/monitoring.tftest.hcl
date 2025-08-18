run "plan" {
  command = plan
  assert {
    condition     = helm_release.kube_prometheus_stack.version == "61.3.1"
    error_message = "Prometheus stack version mismatch"
  }
  assert {
    condition     = helm_release.kube_prometheus_stack.namespace == kubernetes_namespace.infra.metadata[0].name
    error_message = "Prometheus stack not in infra namespace"
  }
}
