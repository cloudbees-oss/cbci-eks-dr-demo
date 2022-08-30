# Common
##########################

variable "aws_region" {
  type        = string
  description = "Alpha AWS region"
}

variable "aws_profile" {
  type        = string
  description = "AWS profile"
}

variable "domain_name" {
  type = string
}

variable "tags" {
  default = {}
  type    = map(string)
}

# 00 Day
##########################

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

variable "cidr_block" {
  default = "10.0.0.0/16"
  type    = string

  validation {
    condition     = try(cidrhost(var.cidr_block, 0), null) != null
    error_message = "CIDR block was not in a valid CIDR format."
  }
}

variable "instance_types" {
  default = ["m5.xlarge", "m5a.xlarge", "m4.xlarge"]
  type    = set(string)
}

variable "key_name" {
  default = ""
  type    = string
}

variable "kubernetes_version" {
  default = "1.21"
  type    = string

  validation {
    condition     = contains(["1.19", "1.20", "1.21"], var.kubernetes_version)
    error_message = "Provided Kubernetes version is not supported by EKS and/or CloudBees."
  }
}

variable "ssh_cidr_blocks" {
  default = ["0.0.0.0/32"]
  type    = list(string)

  validation {
    condition     = contains([for block in var.ssh_cidr_blocks : try(cidrhost(block, 0), "")], "") == false
    error_message = "List of SSH CIDR blocks contains an invalid CIDR block."
  }
}


variable "nodes_taints" {
  default = ["apps", "build"]
  type    = list(string)

  validation {
    condition     = length([var.nodes_taints]) != 2
    error_message = "Taints values needs to be 2."
  }
  validation {
    condition     = contains([for taint in var.nodes_taints : trim(taint, " ")], "") == false
    error_message = "Taints can not be null."
  }

}

# 01 Day
##########################

variable "kubeconfig_file" {
  default = "~/.kube/config"
  type    = string
}
