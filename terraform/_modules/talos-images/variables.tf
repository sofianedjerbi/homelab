# Talos Image Builder Module - Variables

variable "talos_version" {
  description = "Talos version to build/check"
  type        = string
}

variable "hcloud_token" {
  description = "Hetzner Cloud API token"
  type        = string
}

variable "packer_cache_dir" {
  description = "Directory to cache hcloud-talos repository"
  type        = string
  default     = "/tmp/hcloud-talos-cache"
}
