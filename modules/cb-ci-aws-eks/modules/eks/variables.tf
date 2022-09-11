
variable "domain_name" {
  type = string
}

variable "tags" {
  default = {}
  type    = map(string)
}

variable "dr_cluster" {
  default = "alpha"
  type    = string

  validation {
    condition     = contains(["alpha", "beta"], var.dr_cluster)
    error_message = "Provided DR cluster code is not valid. Valid values are alpha and beta."
  }
}

variable "primary_cluster" {
  description = "Flag to set primary cluster."
  type        = bool
}

variable "instance_types" {
  default = ["m5.xlarge", "m5a.xlarge", "m4.xlarge"]
  type    = set(string)
}

variable "kubernetes_version" {
  default = "1.21"
  type    = string

  validation {
    condition     = contains(["1.19", "1.20", "1.21"], var.kubernetes_version)
    error_message = "Provided Kubernetes version is not supported by EKS and/or CloudBees."
  }
}

variable "cidr_block" {
  default = "10.0.0.0/16"
  type    = string

  validation {
    condition     = try(cidrhost(var.cidr_block, 0), null) != null
    error_message = "CIDR block was not in a valid CIDR format."
  }
}

# variable "vpc_id" {
#   type = string
# }

# variable "private_subnet_ids" {
#   type = set(string)
# }

variable "bucket_region" {
  type = string
}
