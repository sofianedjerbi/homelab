# Lab AWS Infrastructure
# CloudFront + ACM + Route53

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
  source = "${get_repo_root()}/terraform/modules/dns-cdn"
}

# Generate AWS provider with us-east-1 alias for ACM
generate "aws_provider" {
  path      = "provider_aws.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  region = "${get_env("AWS_REGION", "eu-central-1")}"
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}
EOF
}

inputs = {
  domain    = get_env("LAB_DOMAIN", "lab.sofianedjerbi.com")
  origin_ip = dependency.hetzner.outputs.public_ipv4_list[0]

  # CloudFront settings
  origin_port     = 8080
  origin_protocol = "http-only"  # Origin uses HTTP, CloudFront terminates TLS
  price_class     = "PriceClass_100"  # EU, US, Canada only (cheapest)

  tags = {
    Environment = "lab"
    Cluster     = "lab-01"
  }
}
