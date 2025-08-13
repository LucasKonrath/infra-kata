resource "helm_release" "jenkins" {
  name       = "jenkins"
  repository = "https://charts.jenkins.io"
  chart      = "jenkins"
  # version intentionally omitted to pull latest available. Pin with: version = "<chart-version>"
  namespace  = kubernetes_namespace.infra.metadata[0].name

  timeout         = 600          # increase to avoid context deadline exceeded
  wait            = true         # wait for resources to become ready
  wait_for_jobs   = true
  atomic          = true         # rollback on failure
  cleanup_on_fail = true

  values = [<<-YAML
controller:
  # Updated per deprecation: adminUser -> admin.username
  admin:
    username: ${var.jenkins_admin_user}
  # To use a fixed password, add below (optional):
  #   password: <password>
  installPlugins:
    - kubernetes
    - workflow-aggregator
    - git
    - configuration-as-code
    - credentials-binding
  JCasC:
    enabled: true
    configScripts:
      pipelines: |
        jenkins:
          systemMessage: "Jenkins configured as code - Infra Kata"
  persistence:
    enabled: false  # disable for Minikube to avoid PVC pending; set true with storageclass later
  resources:
    requests:
      cpu: 200m
      memory: 512Mi
    limits:
      cpu: 1
      memory: 1Gi
YAML
  ]

  depends_on = [kubernetes_namespace.infra]
}
