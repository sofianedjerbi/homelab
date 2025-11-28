# Lab Hetzner Cluster
# Single-node Talos cluster on Hetzner Cloud

include "root" {
  path = find_in_parent_folders("root.hcl")
}

dependency "talos_images" {
  config_path = "../../_dependencies/talos-images"
  skip_outputs = true
}

terraform {
  source = "tfr:///hcloud-talos/talos/hcloud?version=2.20.3"
}

# Write kubeconfig and talosconfig to talos/ directory
generate "local_configs" {
  path      = "local_configs.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
resource "local_file" "kubeconfig" {
  content         = local.kubeconfig
  filename        = "${get_repo_root()}/talos/kubeconfig"
  file_permission = "0600"
}

resource "local_file" "talosconfig" {
  content         = data.talos_client_configuration.this.talos_config
  filename        = "${get_repo_root()}/talos/talosconfig"
  file_permission = "0600"
}
EOF
}

inputs = {
  # Cluster identification
  cluster_name = "lab-01"
  cluster_domain = "lab-01.local"

  # Optional: Set a stable public API endpoint
  # cluster_api_host = "kube.yourdomain.com"  # You'd need to create DNS A record

  # Datacenter
  datacenter_name = "nbg1-dc3"  # Nuremberg

  # Control plane configuration (single node for learning)
  control_plane_count       = 1
  control_plane_server_type = "cx22"  # Small instance for learning (cheaper than CX43)

  # No workers for single-node cluster
  worker_count = 0

  # Allow workloads on control plane (required for single-node)
  allow_scheduling_on_control_planes = true

  # Network CIDRs (optional - defaults are fine)
  # network_ipv4_cidr  = "10.0.0.0/16"
  # pod_ipv4_cidr      = "10.244.0.0/16"
  # service_ipv4_cidr  = "10.96.0.0/12"

  # Cilium with Gateway API enabled
  cilium_values = [
    file("${get_repo_root()}/infrastructure/cilium/values.yaml")
  ]

  # Firewall rules for Gateway API
  extra_firewall_rules = [
    {
      direction   = "in"
      protocol    = "tcp"
      port        = "80"
      source_ips  = ["0.0.0.0/0", "::/0"]
      description = "HTTP"
    },
    {
      direction   = "in"
      protocol    = "tcp"
      port        = "443"
      source_ips  = ["0.0.0.0/0", "::/0"]
      description = "HTTPS"
    }
  ]
}
