# DNS Module Outputs

output "domain" {
  description = "The configured domain"
  value       = var.domain
}

output "fqdn" {
  description = "Fully qualified domain name"
  value       = aws_route53_record.this.fqdn
}

output "zone_id" {
  description = "Route53 zone ID"
  value       = data.aws_route53_zone.this.zone_id
}
