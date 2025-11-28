# DNS Module
# Sets up Route53 DNS record pointing to origin IP

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

locals {
  # Extract root domain from subdomain (e.g., lab.sofianedjerbi.com -> sofianedjerbi.com)
  domain_parts = split(".", var.domain)
  root_domain  = join(".", slice(local.domain_parts, length(local.domain_parts) - 2, length(local.domain_parts)))

  tags = merge(var.tags, {
    ManagedBy = "terraform"
    Module    = "dns"
  })
}

# Look up the hosted zone by domain name
data "aws_route53_zone" "this" {
  name         = "${local.root_domain}."
  private_zone = false
}

# DNS A record pointing to origin IP
resource "aws_route53_record" "this" {
  zone_id = data.aws_route53_zone.this.zone_id
  name    = var.domain
  type    = "A"
  ttl     = 300
  records = [var.origin_ip]
}

# Additional subdomain A records (e.g., argo.lab.sofianedjerbi.com)
resource "aws_route53_record" "subdomains" {
  for_each = toset(var.additional_subdomains)

  zone_id = data.aws_route53_zone.this.zone_id
  name    = "${each.value}.${var.domain}"
  type    = "A"
  ttl     = 300
  records = [var.origin_ip]
}
