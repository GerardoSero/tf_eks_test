variable "cluster_name" {
  type    = string
  default = "tf-eks-demo"
}

variable "profile" {
  type    = string
  default = "sandbox"
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "eks_autoscaling_enabled" {
  type    = bool
  default = false
}

variable "eks_cloudwatch_enabled" {
  type    = bool
  default = false
}

variable "eks_overprovisioning_enabled" {
  type    = bool
  default = true
}

variable "k8s_test_services_enabled" {
  type    = bool
  default = false
}

variable "prometheus_enabled" {
  type    = bool
  default = true
}

variable "ingress_type" {
  type    = string
  default = "nginx"
}

variable "ingress_external_dns_enabled" {
  type    = bool
  default = true
}

variable "admin_access_cidr" {
  type = string
}

variable "public_domain" {
  type    = string
  default = "example.com"
}
