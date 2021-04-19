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

variable "admin_access_cidr" {
  type = string
}
