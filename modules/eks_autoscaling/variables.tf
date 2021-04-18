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

variable "service_accout_name" {
  type    = string
  default = "cluster-autoscaler"
}

variable "namespace" {
  type    = string
  default = "cluster-autoscaler"
}

variable "overprovisioning" {
  type    = string
  default = "linear"
  validation {
    condition     = contains(["disabled", "linear"], var.overprovisioning)
    error_message = "The overprovisioning parameter has an unknow value."
  }
}

variable "overprovisioning_linear" {
  type = object({
    coresPerReplica = number
    nodesPerReplica = number
    min             = number
    max             = number
  })

  default = {
    coresPerReplica = 1
    nodesPerReplica = 1
    min             = 1
    max             = 100
  }
}

variable "overprovisioning_resource_request" {
  type = object({
    cpu    = string
    memory = string
  })

  default = {
    cpu    = "250m"
    memory = "250Mi"
  }
}