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

