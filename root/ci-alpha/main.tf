module "cb-ci" {
  source           = "../../modules/cb-ci-aws-eks"
  aws_region       = var.aws_region
  aws_profile      = var.aws_profile
  domain_name      = var.domain_name
  ci_chart_version = var.ci_chart_version
  primary_cluster  = var.primary_cluster
  dr_cluster       = var.dr_cluster
  tags             = var.tags
}


