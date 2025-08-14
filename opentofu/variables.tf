variable "kubeconfig" {
  type        = string
  description = "Path to kubeconfig"
  default     = "~/.kube/config"
}

variable "jenkins_admin_user" {
  type        = string
  default     = "admin"
}

variable "jenkins_namespace" {
  type    = string
  default = "infra"
}

variable "apps_namespace" {
  type    = string
  default = "apps"
}

variable "registry_nodeport" {
  type        = number
  default     = 32000
  description = "NodePort used to expose Minikube addon registry"
}

variable "registry_direct_nodeport" {
  type        = number
  default     = 32001
  description = "NodePort exposing registry container port 5000 directly (registry-direct service)"
}
