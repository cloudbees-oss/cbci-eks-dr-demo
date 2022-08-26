################################################################################
# Main 01: Application Layer
# Different configuration for Primary and Secondary clusters
################################################################################
locals {
  platform      = "eks"
  ingress_class = "alb"
  ingress_annotations = lookup({
    alb = {
      "alb.ingress.kubernetes.io/scheme"      = "internet-facing"
      "alb.ingress.kubernetes.io/tags"        = join(",", [for k, v in var.tags : "${k}=${v}"])
      "alb.ingress.kubernetes.io/target-type" = "ip"
    },
  }, local.ingress_class, {})
}

################################################################################
# CloudBees CI Pre-requisites for EKS
################################################################################

module "aws_load_balancer_controller" {
  count      = var.primary_cluster && var.deploy_apps ? 1 : 0
  depends_on = [module.eks]
  source     = "../../modules/aws-load-balancer-controller"

  aws_account_id            = local.aws_account_id
  aws_region                = local.aws_region
  cluster_name              = local.cluster_name
  cluster_security_group_id = module.eks.cluster_security_group_id
  node_security_group_id    = module.eks.node_security_group_id
  oidc_issuer               = local.oidc_issuer
}

module "external_dns" {
  count      = var.primary_cluster && var.deploy_apps ? 1 : 0
  depends_on = [module.eks]
  source     = "../../modules/external-dns-eks"

  aws_account_id  = local.aws_account_id
  cluster_name    = local.cluster_name
  oidc_issuer     = local.oidc_issuer
  route53_zone_id = data.aws_route53_zone.domain.id
}

################################################################################
# CloudBees CI
################################################################################

locals {
  ci_host_name   = "${var.ci_subdomain}.${var.domain_name}"
  cjoc_url       = "https://${local.ci_host_name}/cjoc"
  oc_bundle_data = { for file in fileset(local.oc_bundle_dir, "*.{yml,yaml}") : file => file("${local.oc_bundle_dir}/${file}") }
  oc_bundle_dir  = "${path.module}/${var.bundle_dir}"
  oc_groovy_data = { for file in fileset(local.oc_groovy_dir, "*.groovy") : file => file("${local.oc_groovy_dir}/${file}") }
  oc_groovy_dir  = "${path.module}/${var.groovy_dir}"
  oc_secret_data = fileexists(var.secrets_file) ? yamldecode(file(var.secrets_file)) : {}
}

data "template_file" "jenkins_template" {
  template = file("${local.oc_bundle_dir}/general.yaml.tpl")
  vars = {
    CI_URL           = local.cjoc_url
    CASC_BUNDLE_REPO = var.scm_bundle_store
  }
}

module "cloudbees_ci" {
  depends_on = [module.aws_load_balancer_controller, data.template_file.jenkins_template]
  count      = var.primary_cluster && var.deploy_apps ? 1 : 0
  source     = "../../modules/cloudbees-ci"

  agent_image                = var.agent_image
  bundle_data                = merge(local.oc_bundle_data, { "general.yaml" = data.template_file.jenkins_template.rendered })
  chart_version              = var.ci_chart_version
  controller_image           = var.controller_image
  create_servicemonitors     = var.create_servicemonitors
  extra_groovy_configuration = local.oc_groovy_data
  host_name                  = local.ci_host_name
  ingress_annotations        = local.ingress_annotations
  ingress_class              = local.ingress_class
  oc_cpu                     = 2
  oc_image                   = var.oc_image
  oc_memory                  = 4
  namespace                  = var.ci_namespace
  oc_configmap_name          = var.oc_configmap_name
  platform                   = local.platform
  secret_data                = local.oc_secret_data
}

################################################################################
# Velero
################################################################################

module "aws_s3_backups" {
  source = "../../modules/aws-s3"

  bucket_name              = local.s3_backup_name
  private_acl              = false
  versioning_configuration = false
  encryption               = false
  public_access_block      = false
}

module "velero_aws" {
  count      = var.deploy_apps ? 1 : 0
  source     = "../../modules/velero-eks"
  depends_on = [module.eks]

  k8s_cluster_oidc_arn = local.oidc_provider_arn
  region_name          = local.aws_region

  s3_bucket_arn = module.aws_s3_backups.bucket_arn
  bucket_name   = local.s3_backup_name
}
