resource "helm_release" "kube_prometheus_stack" {
  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = "61.3.1" # pin version
  namespace  = kubernetes_namespace.infra.metadata[0].name

  values = [<<-YAML
prometheus:
  prometheusSpec:
    podMonitorSelectorNilUsesHelmValues: false
    serviceMonitorSelectorNilUsesHelmValues: false
    retention: 24h
    resources:
      requests:
        cpu: 200m
        memory: 512Mi
      limits:
        cpu: 1
        memory: 1Gi
alertmanager:
  enabled: false
grafana:
  adminPassword: prom-operator
  defaultDashboardsEnabled: true
  sidecar:
    dashboards:
      enabled: true
    datasources:
      enabled: true
YAML
  ]

  depends_on = [kubernetes_namespace.infra]
}
