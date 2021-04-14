variable "admin_access_cidr" {
  type = string
}

variable "cluster_name" {
  type    = string
  default = "terraform-eks-demo"
}

variable "cluster_version" {
  type = string
}