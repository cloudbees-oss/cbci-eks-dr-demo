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
