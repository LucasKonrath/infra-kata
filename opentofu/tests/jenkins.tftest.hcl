run "plan" {
  command = plan
  assert {
    condition     = helm_release.jenkins.name == "jenkins"
    error_message = "Jenkins release name mismatch"
  }
  assert {
    condition     = helm_release.jenkins.namespace == kubernetes_namespace.infra.metadata[0].name
    error_message = "Jenkins release not in infra namespace"
  }
}
