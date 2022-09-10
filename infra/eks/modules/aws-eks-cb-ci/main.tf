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

module "acm_certificate" {
  source = "./../acm-certificate"

  domain_name = var.domain_name
  subdomain   = "*"
}

module "eks" {
  source          = "./modules/eks"
  domain_name     = var.domain_name
  primary_cluster = var.primary_cluster
  dr_cluster      = var.dr_cluster
  tags            = var.tags
}

module "aws_s3_backups" {
  count  = var.dr_cluster == "beta" ? 1 : 0
  source = "terraform-aws-modules/s3-bucket/aws"

  bucket = local.s3_backup_name
  acl    = "private"

  versioning = {
    enabled = true
  }

}
