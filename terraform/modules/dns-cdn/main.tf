# DNS and CDN Module
# Sets up Route53 DNS, ACM certificate, and CloudFront distribution

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
  tags = merge(var.tags, {
    ManagedBy = "terraform"
    Module    = "dns-cdn"
  })
}

# ACM Certificate (must be in us-east-1 for CloudFront)
resource "aws_acm_certificate" "this" {
  provider          = aws.us_east_1
  domain_name       = var.domain
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = local.tags
}

# DNS validation record for ACM
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.this.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = var.zone_id
}

# Wait for certificate validation
resource "aws_acm_certificate_validation" "this" {
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.this.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

# CloudFront distribution
resource "aws_cloudfront_distribution" "this" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "CDN for ${var.domain}"
  default_root_object = ""
  aliases             = [var.domain]
  price_class         = var.price_class

  origin {
    domain_name = var.origin_ip
    origin_id   = "hetzner-origin"

    custom_origin_config {
      http_port              = var.origin_port
      https_port             = 443
      origin_protocol_policy = var.origin_protocol
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "hetzner-origin"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    # Pass all headers to origin (no caching, acts as reverse proxy)
    cache_policy_id          = aws_cloudfront_cache_policy.no_cache.id
    origin_request_policy_id = aws_cloudfront_origin_request_policy.all_viewer.id
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.this.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  tags = local.tags

  depends_on = [aws_acm_certificate_validation.this]
}

# Cache policy - no caching (pass-through)
resource "aws_cloudfront_cache_policy" "no_cache" {
  name        = "${replace(var.domain, ".", "-")}-no-cache"
  comment     = "No caching policy for ${var.domain}"
  default_ttl = var.cache_default_ttl
  max_ttl     = 31536000
  min_ttl     = 0

  parameters_in_cache_key_and_forwarded_to_origin {
    cookies_config {
      cookie_behavior = "all"
    }
    headers_config {
      header_behavior = "none"
    }
    query_strings_config {
      query_string_behavior = "all"
    }
  }
}

# Origin request policy - forward all headers
resource "aws_cloudfront_origin_request_policy" "all_viewer" {
  name    = "${replace(var.domain, ".", "-")}-all-viewer"
  comment = "Forward all viewer headers for ${var.domain}"

  cookies_config {
    cookie_behavior = "all"
  }

  headers_config {
    header_behavior = "allViewer"
  }

  query_strings_config {
    query_string_behavior = "all"
  }
}

# DNS record pointing to CloudFront
resource "aws_route53_record" "this" {
  zone_id = var.zone_id
  name    = var.domain
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.this.domain_name
    zone_id                = aws_cloudfront_distribution.this.hosted_zone_id
    evaluate_target_health = false
  }
}

# AAAA record for IPv6
resource "aws_route53_record" "this_ipv6" {
  zone_id = var.zone_id
  name    = var.domain
  type    = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.this.domain_name
    zone_id                = aws_cloudfront_distribution.this.hosted_zone_id
    evaluate_target_health = false
  }
}
