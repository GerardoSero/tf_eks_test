variable "name" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "cluster_name" {
  type = string
}

variable "cluster_ca" {
  type = string
}

variable "cluster_endpoint" {
  type = string
}

variable "node_role_arn" {
  type = string
}

variable "node_ami_version" {
  type = string
}

variable "node_key_name" {
  type = string
}

variable "node_security_group_id" {
  type = string
}