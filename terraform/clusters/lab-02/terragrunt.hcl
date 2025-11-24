# Lab-02 Cluster Configuration
# Multi-node Talos cluster for advanced learning

include "root" {
  path = find_in_parent_folders("root.hcl")
}

# Ensure Talos images exist before deploying cluster
dependency "talos_images" {
  config_path = "../../_dependencies/talos-images"

  # We don't need outputs, just ensure images are built first
  skip_outputs = true
}

terraform {
  source = "tfr:///hcloud-talos/talos/hcloud?version=2.20.3"
}

inputs = {
  # Cluster identification
  cluster_name = "lab-02"
  cluster_domain = "lab-02.local"

  # Datacenter
  datacenter_name = "fsn1-dc14"  # Falkenstein (different DC)

  # Control plane configuration (3 for HA learning)
  control_plane_count       = 3
  control_plane_server_type = "cax11"  # ARM instances (cheaper)

  # Workers
  worker_count       = 2
  worker_server_type = "cax11"

  # Don't allow workloads on control plane (proper HA setup)
  allow_scheduling_on_control_planes = false
}
