variable "aws_region" {
  type        = string
  description = "Alpha AWS region"
}

variable "aws_profile" {
  type        = string
  description = "AWS profile"
}

variable "ci_subdomain" {
  default = "ci"
  type    = string
}

variable "domain_name" {
  type = string
}

variable "ci_chart_version" {}

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

variable "s3_bucket_region_dr" {
  description = "AWS Region for the S3 bucket used for DR scenarios."
  type        = string
  default     = "us-east-2"
}
