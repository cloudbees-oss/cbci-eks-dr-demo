
module "ci_common" {
  source           = "../../modules/common-ci"
  aws_region       = var.aws_region
  aws_profile      = var.aws_profile
  domain_name      = var.domain_name
  primary_cluster  = var.primary_cluster
  dr_cluster       = var.dr_cluster
  scm_bundle_store = var.scm_bundle_store
  ci_chart_version = var.ci_chart_version
  deploy_apps      = var.deploy_apps
  tags             = var.tags
}
