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

  # Allow managing namespace-scoped RBAC objects required by some charts (e.g., KEDA certs Role)
  rule {
    api_groups = ["rbac.authorization.k8s.io"]
    resources  = ["roles", "rolebindings"]
    verbs      = ["get", "list", "watch", "create", "update", "patch"]
  }

  # Allow managing KEDA namespace-scoped CRDs used by the app deployment
  rule {
    api_groups = ["keda.sh"]
    resources  = ["scaledobjects", "scaledjobs", "triggerauthentications"]
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

# Cluster-scope minimal read access so Jenkins can verify namespaces, resolve node IP, and read registry service
resource "kubernetes_cluster_role" "jenkins_namespaces_read" {
  metadata {
    name = "jenkins-namespaces-read"
  }
  # existing namespaces rule
  rule {
    api_groups = [""]
    resources  = ["namespaces"]
    verbs      = ["get", "list"]
  }
  # add nodes read for Minikube IP resolution
  rule {
    api_groups = [""]
    resources  = ["nodes"]
    verbs      = ["get", "list"]
  }
  # allow reading services/endpoints cluster-wide (registry in kube-system)
  rule {
    api_groups = [""]
    resources  = ["services", "endpoints"]
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

# Cluster-scope CRD access so Helm (run by Jenkins) can install / upgrade charts that include CRDs
resource "kubernetes_cluster_role" "jenkins_crd_access" {
  metadata { name = "jenkins-crd-access" }
  rule {
    api_groups = ["apiextensions.k8s.io"]
    resources  = ["customresourcedefinitions"]
    verbs      = ["get", "list", "watch", "create", "update", "patch"]
  }
}

resource "kubernetes_cluster_role_binding" "jenkins_crd_access" {
  metadata { name = "jenkins-crd-access-binding" }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.jenkins_crd_access.metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = "jenkins"
    namespace = kubernetes_namespace.infra.metadata[0].name
  }
  depends_on = [kubernetes_cluster_role.jenkins_crd_access]
}

# Cluster-scope RBAC object management (needed for charts that create/update ClusterRoles/ClusterRoleBindings e.g. KEDA)
resource "kubernetes_cluster_role" "jenkins_cluster_rbac_manager" {
  metadata { name = "jenkins-cluster-rbac-manager" }
  rule {
    api_groups = ["rbac.authorization.k8s.io"]
  # Include namespace-scoped roles/rolebindings so Jenkins can manage chart-created RBAC in kube-system and others
  resources  = ["clusterroles", "clusterrolebindings", "roles", "rolebindings"]
  # Add escalate & bind so Helm (Jenkins) can create ClusterRoles/Bindings that grant permissions it doesn't yet possess (needed for KEDA)
  verbs      = ["get", "list", "watch", "create", "update", "patch", "escalate", "bind"]
  }
  # Allow managing/querying aggregated API registrations (needed for external.metrics.k8s.io APIService in KEDA)
  rule {
    api_groups = ["apiregistration.k8s.io"]
    resources  = ["apiservices"]
    verbs      = ["get", "list", "watch", "create", "update", "patch"]
  }
  # Allow managing admission webhooks required by charts (e.g., KEDA validating webhook)
  rule {
    api_groups = ["admissionregistration.k8s.io"]
    resources  = ["validatingwebhookconfigurations", "mutatingwebhookconfigurations"]
    verbs      = ["get", "list", "watch", "create", "update", "patch"]
  }
}

resource "kubernetes_cluster_role_binding" "jenkins_cluster_rbac_manager" {
  metadata { name = "jenkins-cluster-rbac-manager-binding" }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.jenkins_cluster_rbac_manager.metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = "jenkins"
    namespace = kubernetes_namespace.infra.metadata[0].name
  }
  depends_on = [kubernetes_cluster_role.jenkins_cluster_rbac_manager]
}
