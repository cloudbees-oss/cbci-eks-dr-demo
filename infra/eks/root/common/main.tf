provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
  default_tags {
    tags = var.tags
  }
}

locals {
  s3_backup_name = "velero.${var.dr_cluster}.backup"
}

module "aws_s3_backups" {
  source = "../../modules/aws-s3"

  bucket_name              = local.s3_backup_name
  private_acl              = false
  versioning_configuration = false
  encryption               = false
  public_access_block      = false
}

terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      version = ">= 3.61.0"
    }
  }
}
