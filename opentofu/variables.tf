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
