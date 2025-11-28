# DNS and CDN Module Variables

variable "domain" {
  description = "The domain name (e.g., lab.sofianedjerbi.com)"
  type        = string
}

variable "zone_id" {
  description = "Route53 hosted zone ID"
  type        = string
}

variable "origin_ip" {
  description = "Origin server IP address (Hetzner floating IP)"
  type        = string
}

variable "origin_port" {
  description = "Origin server port"
  type        = number
  default     = 8080
}

variable "origin_protocol" {
  description = "Origin protocol (http or https)"
  type        = string
  default     = "http-only"

  validation {
    condition     = contains(["http-only", "https-only", "match-viewer"], var.origin_protocol)
    error_message = "origin_protocol must be one of: http-only, https-only, match-viewer"
  }
}

variable "price_class" {
  description = "CloudFront price class"
  type        = string
  default     = "PriceClass_100" # US, Canada, Europe only (cheapest)

  validation {
    condition     = contains(["PriceClass_100", "PriceClass_200", "PriceClass_All"], var.price_class)
    error_message = "price_class must be one of: PriceClass_100, PriceClass_200, PriceClass_All"
  }
}

variable "cache_default_ttl" {
  description = "Default TTL for cached objects (seconds)"
  type        = number
  default     = 0 # No caching by default (pass-through to origin)
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
