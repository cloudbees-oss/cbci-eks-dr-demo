################################################################################
# Main 00: Infrastructure Layer
################################################################################

data "aws_caller_identity" "current" {}

data "aws_availability_zones" "available" {}

data "aws_eks_cluster_auth" "auth" {
  name = module.eks.cluster_id
}

data "aws_region" "current" {}

data "aws_route53_zone" "domain" {
  name = var.domain_name
}

locals {
  s3_backup_name         = "velero.${var.dr_cluster}"
  availability_zones     = slice(data.aws_availability_zones.available.names, 0, 3)
  aws_account_id         = data.aws_caller_identity.current.account_id
  aws_region             = data.aws_region.current.name
  cluster_auth_token     = data.aws_eks_cluster_auth.auth.token
  cluster_endpoint       = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  cluster_name           = "dr-ci-demo-${var.dr_cluster}"
  oidc_issuer            = trimprefix(module.eks.cluster_oidc_issuer_url, "https://")
  oidc_provider_arn      = module.eks.oidc_provider_arn
  this                   = toset(["this"])

  vpc_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "dr-environmet"                               = terraform.workspace
  }

  alb_annotations = {
    "alb.ingress.kubernetes.io/actions.ssl-redirect" = "{\"Type\": \"redirect\", \"RedirectConfig\": { \"Protocol\": \"HTTPS\", \"Port\": \"443\", \"StatusCode\": \"HTTP_301\"}}"
    "alb.ingress.kubernetes.io/listen-ports"         = "[{\"HTTP\": 80}, {\"HTTPS\":443}]"
    "alb.ingress.kubernetes.io/scheme"               = "internet-facing"
    "alb.ingress.kubernetes.io/tags"                 = join(",", [for k, v in var.tags : "${k}=${v}"])
    "alb.ingress.kubernetes.io/target-type"          = "ip"
  }

}

################################################################################
# Amazon EKS cluster
################################################################################

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.13.0"

  name                 = "${local.cluster_name}-vpc"
  cidr                 = var.cidr_block
  azs                  = local.availability_zones
  private_subnets      = [for i in range(0, 3) : cidrsubnet(var.cidr_block, 8, 100 + i)]
  public_subnets       = [for i in range(0, 3) : cidrsubnet(var.cidr_block, 8, 200 + i)]
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  public_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"             = "1"
  }

  tags = local.vpc_tags
}

module "iam" {
  source = "./modules/eks-iam-roles"

  cluster_name = local.cluster_name
}

module "eks" {
  depends_on = [module.vpc, module.iam]
  source     = "terraform-aws-modules/eks/aws"
  version    = "18.17.0"

  cluster_name                = local.cluster_name
  cluster_version             = var.kubernetes_version
  create_iam_role             = false
  enable_irsa                 = true
  iam_role_arn                = module.iam.cluster_role_arn
  subnet_ids                  = module.vpc.private_subnets
  vpc_id                      = module.vpc.vpc_id
  create_cloudwatch_log_group = false

  eks_managed_node_group_defaults = {
    min_size     = 1
    max_size     = 4
    desired_size = 1

    create_iam_role       = false
    create_security_group = false
    iam_role_arn          = module.iam.node_role_arn
    instance_types        = var.instance_types
    key_name              = var.key_name
    labels                = {}
    launch_template_tags  = var.tags
  }

  eks_managed_node_groups = {
    "${local.cluster_name}-cluster" = {
      subnet_ids = [module.vpc.private_subnets[0]]
    }
    "${local.cluster_name}-apps" = {
      subnet_ids = [module.vpc.private_subnets[1]]
      taints = {
        "${var.nodes_taints[0]}" = {
          key    = "dedicated"
          value  = "${var.nodes_taints[0]}"
          effect = "NO_SCHEDULE"
        }
      }
    }
    "${local.cluster_name}-build" = {
      subnet_ids = [module.vpc.private_subnets[2]]
      taints = {
        "${var.nodes_taints[1]}" = {
          key    = "dedicated"
          value  = "${var.nodes_taints[1]}"
          effect = "NO_SCHEDULE"
        }
      }
    }
  }

  node_security_group_additional_rules = {
    egress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "egress"
      self        = true
    }

    ingress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }
  }
}

################################################################################
# Cluster Components
################################################################################

module "acm_certificate" {
  count  = var.primary_cluster && var.deploy_apps ? 1 : 0
  source = "./modules/acm-certificate"

  domain_name = var.domain_name
  subdomain   = "*"
}

module "cluster_autoscaler" {
  depends_on = [module.eks]
  source     = "./modules/cluster-autoscaler-eks"

  aws_account_id     = local.aws_account_id
  aws_region         = local.aws_region
  cluster_name       = local.cluster_name
  kubernetes_version = var.kubernetes_version
  oidc_issuer        = local.oidc_issuer
  patch_version      = 2
}

module "cluster_metrics" {
  depends_on = [module.eks]
  source     = "./modules/metrics-server"
}
