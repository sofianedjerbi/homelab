# etcd.me Environment
# Production-grade Kubernetes cluster on Hetzner Cloud

locals {
  cluster_name = "etcdme"
  domain       = "etcd.me"
}

# Kubernetes cluster (includes firewall, floating IP, Cilium, Cert-Manager, Longhorn)
unit "cluster" {
  source = "../../modules/cluster"
  path   = "cluster"

  values = {
    cluster_name = local.cluster_name
    hcloud_token = get_env("HCLOUD_TOKEN")

    # Control plane nodes (3 for HA)
    control_plane_nodepools = [
      {
        name     = "control-plane"
        type     = "cx22"
        location = "nbg1"
        count    = 3
      }
    ]

    # No separate workers - schedule on control planes
    worker_nodepools = []

    # Gateway API support (installs CRDs + enables Cilium Gateway controller)
    gateway_api_enabled      = true
    gateway_api_version      = "v1.4.1"
    gateway_api_experimental = true  # Includes TLSRoute
  }
}

# DNS records
unit "dns" {
  source = "../../modules/dns"
  path   = "dns"

  values = {
    domain                = local.domain
    additional_subdomains = ["argo", "kube", "loki", "n8n", "auth"]

    # Get floating IP from cluster output
    cluster_path = "../cluster"

    tags = {
      Environment = "production"
      Cluster     = local.cluster_name
    }
  }
}
