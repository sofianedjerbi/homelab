# Lab AWS Infrastructure
# Route53 DNS record

include "root" {
  path = find_in_parent_folders("root.hcl")
}

dependency "hetzner" {
  config_path = "../hetzner"

  mock_outputs = {
    public_ipv4_list = ["0.0.0.0"]
  }
}

terraform {
  source = "${get_repo_root()}/terraform/modules/dns"
}

generate "aws_provider" {
  path      = "provider_aws.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  region = "${get_env("AWS_REGION", "eu-central-1")}"
}
EOF
}

inputs = {
  domain    = get_env("LAB_DOMAIN", "lab.sofianedjerbi.com")
  origin_ip = dependency.hetzner.outputs.public_ipv4_list[0]

  # Additional subdomains pointing to the same IP
  additional_subdomains = ["argo"]

  tags = {
    Environment = "lab"
  }
}
