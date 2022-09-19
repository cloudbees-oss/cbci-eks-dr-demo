data "aws_eks_cluster_auth" "this" {
  name = module.eks_blueprints.eks_cluster_id
}

data "aws_availability_zones" "available" {}

data "aws_route53_zone" "domain" {
  name = local.domain_name
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

locals {
  name            = "blueprint-test1"
  cluster_version = "1.23"
  domain_name     = "dw22.pscbdemos.com"
  aws_account_id  = data.aws_caller_identity.current.account_id
  aws_region      = data.aws_region.current.name

  vpc_cidr = "10.0.0.0/16"
  azs      = slice(data.aws_availability_zones.available.names, 0, 2)

  tags = {
    Blueprint  = local.name
    GithubRepo = "github.com/aws-ia/terraform-aws-eks-blueprints"
  }

  ci_host_name  = "ci.${local.domain_name}"
  cjoc_url      = "https://${local.ci_host_name}/cjoc"
  ingress_class = "alb"
  ingress_annotations = {
    "alb.ingress.kubernetes.io/scheme"      = "internet-facing"
    "alb.ingress.kubernetes.io/tags"        = join(",", [for k, v in local.tags : "${k}=${v}"])
    "alb.ingress.kubernetes.io/target-type" = "ip"
  }
  platform         = "eks"
  ci_chart_version = "3.48.1+f7b88ec23de3"

}

################################################################
# CloudBees CI
################################################################

module "cloudbees_ci" {
  depends_on = [module.eks_blueprints_kubernetes_addons]
  source     = "./modules/cloudbees-ci"

  chart_version       = local.ci_chart_version
  platform            = local.platform
  host_name           = local.ci_host_name
  ingress_annotations = local.ingress_annotations
  ingress_class       = local.ingress_class
  oc_cpu              = 1
  oc_memory           = 2
}