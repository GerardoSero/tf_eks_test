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

variable "admin_access_cidr" {
  type = string
}
