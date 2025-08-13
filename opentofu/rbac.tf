# RBAC to allow Jenkins (in infra namespace) to deploy Helm releases into apps namespace
resource "kubernetes_role" "jenkins_deployer" {
  metadata {
    name      = "jenkins-deployer"
    namespace = kubernetes_namespace.apps.metadata[0].name
    labels = {
      app = "jenkins"
    }
  }

  rule {
    api_groups = [""]
    resources  = ["secrets", "configmaps"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  rule {
    api_groups = [""]
    resources  = ["services", "serviceaccounts", "endpoints"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  rule {
    api_groups = ["apps"]
    resources  = ["deployments", "replicasets"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  rule {
    api_groups = ["monitoring.coreos.com"]
    resources  = ["servicemonitors"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }
}

resource "kubernetes_role_binding" "jenkins_deployer" {
  metadata {
    name      = "jenkins-deployer-binding"
    namespace = kubernetes_namespace.apps.metadata[0].name
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.jenkins_deployer.metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = "jenkins"
    namespace = kubernetes_namespace.infra.metadata[0].name
  }
  depends_on = [kubernetes_role.jenkins_deployer]
}

# Cluster-scope minimal read access so Jenkins can verify namespaces (Option B)
resource "kubernetes_cluster_role" "jenkins_namespaces_read" {
  metadata {
    name = "jenkins-namespaces-read"
  }
  rule {
    api_groups = [""]
    resources  = ["namespaces"]
    verbs      = ["get", "list"]
  }
}

resource "kubernetes_cluster_role_binding" "jenkins_namespaces_read" {
  metadata {
    name = "jenkins-namespaces-read-binding"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.jenkins_namespaces_read.metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = "jenkins"
    namespace = kubernetes_namespace.infra.metadata[0].name
  }
  depends_on = [kubernetes_cluster_role.jenkins_namespaces_read]
}
