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

variable "dr_cluster" {
  type = string
}

variable "primary_cluster" {
  description = "Flag to set primary cluster."
  type        = bool
  default     = false
}

variable "deploy_apps" {
  description = "Flag to deploy apps. It is used to clean a cluster."
  default     = true
  type        = bool
}


variable "tags" {
  default = {}
  type    = map(string)
}


variable "ci_chart_version" {
  default = "3.45.1+8bd15735adb7" # App version 2.346.2.2 | Date (13 Jul, 2022)
  type    = string
}

variable "scm_bundle_store" {
  type = string
}
