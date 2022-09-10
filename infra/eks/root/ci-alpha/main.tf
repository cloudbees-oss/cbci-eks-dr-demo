module "cb-ci" {
  source          = "../../modules/cb-ci"
  aws_region      = var.aws_region
  aws_profile     = var.aws_profile
  domain_name     = var.domain_name
  primary_cluster = var.primary_cluster
  dr_cluster      = var.dr_cluster
  tags            = var.tags
}
