variable "bucket_name" {
  type = string
}

variable "private_acl" {
  default = false
  type    = bool
}

variable "versioning_configuration" {
  default = false
  type    = bool
}

variable "encryption" {
  default = false
  type    = bool
}

variable "public_access_block" {
  default = false
  type    = bool
}

variable "tags" {
  default = {}
  type    = map(string)
}
