variable "cluster_name" {
  type = string
}

variable "cluster_region" {
  type = string
}

variable "oidc_provider_url" {
  type = string
}

variable "oidc_provider_arn" {
  type = string
}

variable "service_account_name" {
  type    = string
  default = "external-dns"
}
