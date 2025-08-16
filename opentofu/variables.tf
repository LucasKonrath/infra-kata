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

variable "enable_ingress" {
  type        = bool
  default     = true
  description = "Create a shared Ingress (jenkins/grafana/prometheus) using nip.io hosts."
}

variable "minikube_ip_override" {
  type        = string
  default     = ""
  description = "Explicit Minikube IP to use for nip.io hostnames (skips shell lookup)."
}

variable "force_port_forward_refresh" {
  type        = string
  default     = ""
  description = "Change this (e.g. set to a timestamp) to force re-running the port-forward null_resource."
}
