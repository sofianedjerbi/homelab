# Kubernetes cluster on Hetzner Cloud using Talos Linux
# Uses: https://github.com/hcloud-k8s/terraform-hcloud-kubernetes

module "kubernetes" {
  source  = "hcloud-k8s/kubernetes/hcloud"
  version = "~> 3.13"

  cluster_name = var.cluster_name
  hcloud_token = var.hcloud_token

  # Control plane nodes
  control_plane_nodepools = var.control_plane_nodepools

  # Worker nodes (optional)
  worker_nodepools = var.worker_nodepools

  # Floating IP for ingress
  control_plane_public_vip_ipv4_enabled = true

  # Firewall - allow current IP for API access
  firewall_use_current_ipv4 = true

  # Cilium CNI with Gateway API support
  cilium_enabled     = true
  cilium_helm_values = var.cilium_helm_values

  # Cert Manager
  cert_manager_enabled = true

  # Longhorn storage
  longhorn_enabled               = true
  longhorn_default_storage_class = true

  # Disable NGINX ingress (using Cilium Gateway API instead)
  ingress_nginx_enabled = false

  # Talos config patches for extensions
  control_plane_config_patches = var.control_plane_config_patches
  worker_config_patches        = var.worker_config_patches

  # Output configs to files
  cluster_kubeconfig_path  = var.kubeconfig_path
  cluster_talosconfig_path = var.talosconfig_path
}
