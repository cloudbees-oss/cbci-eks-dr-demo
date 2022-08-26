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

variable "s3_backup_name" {
  default = ""
  type    = string
}

variable "tags" {
  default = {}
  type    = map(string)
}

# 00 Day
##########################

variable "cluster_name" {
  type = string
}

variable "primary_cluster" {
  description = "Flag to set primary cluster."
  type        = bool
  default     = false
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

# 1.1.3 - Node pools for Kubernetes installation
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

variable "deploy_apps" {
  description = "Flag to deploy apps. It is used to clean a cluster."
  default     = true
  type        = bool
}


# Options for installing and configuring CloudBees CI

variable "ci_subdomain" {
  default = "ci"
  type    = string
  validation {
    condition     = trim(var.ci_subdomain, " ") != ""
    error_message = "Subdomain can not be empty."
  }
}

variable "agent_image" {
  default = ""
}

variable "create_servicemonitors" {
  default = false
  type    = bool
}

variable "bundle_dir" {
  default = "casc/oc"
  type    = string
}

variable "scm_bundle_store" {
  type = string
}

variable "ci_chart_repository" {
  default = "https://charts.cloudbees.com/public/cloudbees"
  type    = string
}

variable "ci_chart_version" {
  default = "3.45.1+8bd15735adb7" # App version 2.346.2.2 | Date (13 Jul, 2022)
  type    = string
}

variable "ci_namespace" {
  default = "cb-ci"
  type    = string
}

variable "controller_image" {
  default = ""
  type    = string
}

variable "groovy_dir" {
  default = "groovy-init"
  type    = string
}

variable "oc_configmap_name" {
  default = "oc-casc-bundle"
  type    = string
}

variable "oc_image" {
  default = ""
  type    = string
}

variable "secrets_file" {
  default = "values/secrets.yaml"
  type    = string
}

variable "storage_class" {
  default = ""
  type    = string
}

variable "s3_backup_arn" {
  default = ""
  type    = string
}
