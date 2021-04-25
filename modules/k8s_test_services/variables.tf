variable "ingress_type" {
  type    = string
  default = "nginx"
  validation {
    condition     = contains(["none", "nginx", "kong"], var.ingress_type)
    error_message = "The ingress type parameter has an unknow value."
  }
}

variable "public_domain" {
  type = string
}
