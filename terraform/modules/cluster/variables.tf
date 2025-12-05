variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
}

variable "hcloud_token" {
  description = "Hetzner Cloud API token"
  type        = string
  sensitive   = true
}

variable "control_plane_nodepools" {
  description = "Control plane node pool configuration"
  type = list(object({
    name     = string
    type     = string
    location = string
    count    = number
  }))
}

variable "worker_nodepools" {
  description = "Worker node pool configuration"
  type = list(object({
    name     = string
    type     = string
    location = string
    count    = number
  }))
  default = []
}

variable "cilium_helm_values" {
  description = "Custom Helm values for Cilium"
  type        = any
  default     = {}
}

variable "gateway_api_enabled" {
  description = "Enable Gateway API CRDs installation"
  type        = bool
  default     = false
}

variable "gateway_api_version" {
  description = "Gateway API version to install"
  type        = string
  default     = "v1.4.1"
}

variable "gateway_api_experimental" {
  description = "Use experimental Gateway API features (includes TLSRoute)"
  type        = bool
  default     = true
}

variable "control_plane_config_patches" {
  description = "Talos machine config patches for control plane nodes"
  type        = any
  default     = []
}

variable "worker_config_patches" {
  description = "Talos machine config patches for worker nodes"
  type        = any
  default     = []
}

variable "kubeconfig_path" {
  description = "Path to write kubeconfig file"
  type        = string
  default     = null
}

variable "talosconfig_path" {
  description = "Path to write talosconfig file"
  type        = string
  default     = null
}
