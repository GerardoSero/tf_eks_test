variable "ingress_type" {
  type    = string
  default = "nginx"
  validation {
    condition     = contains(["none", "nginx", "kong"], var.ingress_type)
    error_message = "The ingress type parameter has an unknow value."
  }
}

variable "external_dns_enabled" {
  type    = string
  default = false
}

variable "external_dns" {
  type = object({
    cluster_name      = string
    cluster_region    = string
    oidc_provider_url = string
    oidc_provider_arn = string
    dns_zones         = list(string)
  })
}

variable "service_account_name" {
  type    = string
  default = "external-dns"
}
