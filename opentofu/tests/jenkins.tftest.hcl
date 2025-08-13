run "plan" {
  command = plan

  assert {
    condition     = length(regexall("helm_release.jenkins", run.stdout)) > 0
    error_message = "Jenkins release not planned"
  }
}
