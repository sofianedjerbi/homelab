# Cluster module unit
# Deploys Kubernetes cluster on Hetzner Cloud using terraform-hcloud-kubernetes

include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "./"

  after_hook "save_credentials" {
    commands     = ["apply"]
    execute      = ["${get_repo_root()}/terraform/modules/cluster/scripts/save-credentials.sh"]
    run_on_error = false
  }
}

inputs = {
  cluster_name = values.cluster_name
  hcloud_token = values.hcloud_token

  control_plane_nodepools = values.control_plane_nodepools
  worker_nodepools        = try(values.worker_nodepools, [])

  cilium_helm_values           = try(values.cilium_helm_values, {})
  control_plane_config_patches = try(values.control_plane_config_patches, [])
  worker_config_patches        = try(values.worker_config_patches, [])

  kubeconfig_path  = try(values.kubeconfig_path, null)
  talosconfig_path = try(values.talosconfig_path, null)

  # Gateway API
  gateway_api_enabled      = try(values.gateway_api_enabled, false)
  gateway_api_version      = try(values.gateway_api_version, "v1.4.1")
  gateway_api_experimental = try(values.gateway_api_experimental, true)

  # Delete protection
  cluster_delete_protection = try(values.cluster_delete_protection, true)

  # Graceful destroy
  cluster_graceful_destroy = try(values.cluster_graceful_destroy, true)
}
