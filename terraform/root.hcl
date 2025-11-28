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
    skip_metadata_api_check = true
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
