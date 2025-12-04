# Cluster module outputs

output "kubeconfig" {
  description = "Kubeconfig for cluster access"
  value       = module.kubernetes.kubeconfig
  sensitive   = true
}

output "talosconfig" {
  description = "Talosconfig for Talos API access"
  value       = module.kubernetes.talosconfig
  sensitive   = true
}

output "control_plane_ips" {
  description = "Control plane public IPv4 addresses"
  value       = module.kubernetes.control_plane_public_ipv4_list
}

# Primary IP for DNS - first control plane node
output "primary_ip" {
  description = "Primary public IP (first control plane node)"
  value       = module.kubernetes.control_plane_public_ipv4_list[0]
}
