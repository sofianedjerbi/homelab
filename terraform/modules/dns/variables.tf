# DNS Module Variables

variable "domain" {
  description = "The domain name (e.g., lab.sofianedjerbi.com)"
  type        = string
}

variable "origin_ip" {
  description = "Origin server IP address"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
