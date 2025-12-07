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

    # Control plane nodes (3x CX33 for HA with adequate resources)
    control_plane_nodepools = [
      {
        name     = "control-plane"
        type     = "cx33"
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

    # Set false to allow cluster destruction
    cluster_delete_protection  = false
    cluster_graceful_destroy   = false
  }
}

# DNS records
unit "dns" {
  source = "../../modules/dns"
  path   = "dns"

  values = {
    domain                = local.domain
    additional_subdomains = ["argo", "kube", "loki", "n8n", "auth", "uptime"]

    # Get control plane IP from cluster output (for kube subdomain)
    cluster_path = "../cluster"

    # Gateway LoadBalancer IP (from Cilium Gateway -> Hetzner CCM)
    # Subdomains point here for ingress traffic
    gateway_ip = "91.98.5.86"

    tags = {
      Environment = "production"
      Cluster     = local.cluster_name
    }
  }
}
