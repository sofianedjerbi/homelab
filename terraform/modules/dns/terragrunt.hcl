# DNS module unit
# Manages Route53 DNS records

dependency "cluster" {
  config_path = values.cluster_path

  mock_outputs = {
    primary_ip = "0.0.0.0"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

terraform {
  source = "./"
}

inputs = {
  domain                = values.domain
  origin_ip             = dependency.cluster.outputs.primary_ip
  additional_subdomains = try(values.additional_subdomains, [])
  tags                  = try(values.tags, {})
}
