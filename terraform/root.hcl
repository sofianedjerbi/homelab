# Root Terragrunt Configuration
# Uses the mature hcloud-talos module for full automation

# S3 backend for remote state management (AWS SSO compatible)
remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    bucket  = get_env("TF_STATE_BUCKET")
    key     = "${path_relative_to_include()}/terraform.tfstate"
    region  = get_env("AWS_REGION", "us-east-1")
    encrypt = true

    # S3 native state locking (Terraform 1.10+, no DynamoDB needed!)
    use_lockfile = true

    # AWS SSO profile support (optional, access keys via env vars also work)
    profile = get_env("AWS_PROFILE", null)
  }
}

# Generate provider configuration
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  required_version = ">= 1.0"
}
EOF
}

# Automatically write kubeconfig and talosconfig to talos/ directory
generate "local_configs" {
  path      = "local_configs.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
# Write kubeconfig and talosconfig automatically on apply
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

# Common inputs for all clusters
inputs = {
  # Hetzner Cloud
  hcloud_token = get_env("HCLOUD_TOKEN")

  # Versions (from devbox.json - DRY!)
  talos_version      = get_env("TALOS_VERSION")
  kubernetes_version = get_env("KUBERNETES_VERSION")
  cilium_version     = get_env("CILIUM_VERSION")

  # Security
  firewall_use_current_ip = true  # Automatically allow your current IP
}
