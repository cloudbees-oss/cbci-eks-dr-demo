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
  s3_bucket_name  = module.aws_s3_backups.s3_bucket_id
  # s3_bucket_region_dr = var.s3_bucket_region_dr
  tags = var.tags
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
  #count   = var.dr_cluster == "beta" ? 1 : 0
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "3.4.0"

  bucket = local.s3_backup_name

  # Allow deletion of non-empty bucket
  # NOTE: This is enabled for example usage only, you should not enable this for production workloads
  force_destroy = true

  attach_deny_insecure_transport_policy = true
  attach_require_latest_tls_policy      = true

  acl = "private"

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  control_object_ownership = true
  object_ownership         = "BucketOwnerPreferred"

  versioning = {
    status     = true
    mfa_delete = false
  }

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }
  }

}
