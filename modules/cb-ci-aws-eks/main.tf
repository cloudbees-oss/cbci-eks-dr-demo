provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
  default_tags {
    tags = var.tags
  }
}

locals {
  s3_backup_name = "velero.${var.dr_cluster}.backup"
  ci_host_name   = "${var.ci_subdomain}.${var.domain_name}"
  cjoc_url       = "https://${local.ci_host_name}/cjoc"
  ingress_class  = "alb"
  ingress_annotations = {
    "alb.ingress.kubernetes.io/scheme"      = "internet-facing"
    "alb.ingress.kubernetes.io/tags"        = join(",", [for k, v in var.tags : "${k}=${v}"])
    "alb.ingress.kubernetes.io/target-type" = "ip"
  }
  platform = "eks"
}

data "aws_route53_zone" "domain" {
  name = var.domain_name
}

module "acm_certificate" {
  source  = "terraform-aws-modules/acm/aws"
  version = "~> 4.0"

  domain_name = var.domain_name
  zone_id     = data.aws_route53_zone.domain.id

  subject_alternative_names = [
    "*.${var.domain_name}",
  ]

  wait_for_validation = true

}

module "eks" {
  source          = "./modules/eks"
  domain_name     = var.domain_name
  primary_cluster = var.primary_cluster
  dr_cluster      = var.dr_cluster
  tags            = var.tags
}

module "cloudbees_ci" {
  depends_on = [module.eks]
  source     = "./modules/cloudbees-ci"

  chart_version       = var.ci_chart_version
  platform            = local.platform
  host_name           = local.ci_host_name
  ingress_annotations = local.ingress_annotations
  ingress_class       = local.ingress_class
  oc_cpu              = 1
  oc_memory           = 2

}

module "aws_s3_backups" {
  count   = var.dr_cluster == "beta" ? 1 : 0
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "3.4.0"

  bucket = local.s3_backup_name
  acl    = "private"

  versioning = {
    enabled = true
  }
}
