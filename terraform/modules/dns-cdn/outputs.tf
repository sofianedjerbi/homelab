# DNS and CDN Module Outputs

output "domain" {
  description = "The configured domain"
  value       = var.domain
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = aws_cloudfront_distribution.this.id
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name"
  value       = aws_cloudfront_distribution.this.domain_name
}

output "cloudfront_arn" {
  description = "CloudFront distribution ARN"
  value       = aws_cloudfront_distribution.this.arn
}

output "certificate_arn" {
  description = "ACM certificate ARN"
  value       = aws_acm_certificate.this.arn
}

output "url" {
  description = "Full HTTPS URL"
  value       = "https://${var.domain}"
}
