# DNS Module Variables

variable "domain" {
  description = "The domain name (e.g., lab.sofianedjerbi.com)"
  type        = string
}

variable "additional_subdomains" {
  description = "Additional subdomains to create (e.g., ['argo'] creates argo.lab.sofianedjerbi.com)"
  type        = list(string)
  default     = []
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
