variable "aws_region" {
  type        = string
  description = "AWS region"
}

variable "aws_profile" {
  type        = string
  description = "AWS profile"
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
