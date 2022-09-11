data "aws_caller_identity" "current" {}

data "aws_availability_zones" "available" {}

data "aws_eks_cluster_auth" "auth" {
  name = module.eks_blueprints.eks_cluster_id
}

data "aws_region" "current" {}

data "aws_route53_zone" "domain" {
  name = var.domain_name
}

locals {
  availability_zones     = slice(data.aws_availability_zones.available.names, 0, 3)
  aws_account_id         = data.aws_caller_identity.current.account_id
  aws_region             = data.aws_region.current.name
  cluster_auth_token     = data.aws_eks_cluster_auth.auth.token
  cluster_ca_certificate = base64decode(module.eks_blueprints.eks_cluster_certificate_authority_data)
  cluster_name           = "dr-ci-demo-${var.dr_cluster}"
  vpc_cidr               = var.cidr_block
  tags = merge(var.tags, {
    "cluster_name" = "local.cluster_name"
  })
}

#---------------------------------------------------------------
# EKS Blueprints
#---------------------------------------------------------------
module "eks_blueprints" {
  source = "github.com/aws-ia/terraform-aws-eks-blueprints?ref=v4.8.0"

  cluster_name    = local.cluster_name
  cluster_version = var.kubernetes_version

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnets

  node_security_group_additional_rules = {
    # Extend node-to-node security group rules. Recommended and required for the Add-ons
    ingress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }
    # Recommended outbound traffic for Node groups
    egress_all = {
      description      = "Node all egress"
      protocol         = "-1"
      from_port        = 0
      to_port          = 0
      type             = "egress"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
    # Allows Control Plane Nodes to talk to Worker nodes on all ports. Added this to simplify the example and further avoid issues with Add-ons communication with Control plane.
    # This can be restricted further to specific port based on the requirement for each Add-on e.g., metrics-server 4443, spark-operator 8080, karpenter 8443 etc.
    # Change this according to your security requirements if needed
    ingress_cluster_to_node_all_traffic = {
      description                   = "Cluster API to Nodegroup all traffic"
      protocol                      = "-1"
      from_port                     = 0
      to_port                       = 0
      type                          = "ingress"
      source_cluster_security_group = true
    }
  }

  managed_node_groups = {

    mg_5 = {
      node_group_name = "mg_5"
      instance_types  = var.instance_types
      max_size        = 6
      desired_size    = 2
      min_size        = 2
      subnet_ids      = module.vpc.private_subnets
    }

  }

  tags = local.tags
}

module "eks_blueprints_kubernetes_addons" {
  source = "github.com/aws-ia/terraform-aws-eks-blueprints//modules/kubernetes-addons?ref=v4.8.0"

  eks_cluster_id       = module.eks_blueprints.eks_cluster_id
  eks_cluster_endpoint = module.eks_blueprints.eks_cluster_endpoint
  eks_oidc_provider    = module.eks_blueprints.oidc_provider
  eks_cluster_version  = module.eks_blueprints.eks_cluster_version
  eks_cluster_domain   = var.domain_name

  # EKS Managed Add-ons
  enable_amazon_eks_vpc_cni            = true
  enable_amazon_eks_coredns            = true
  enable_amazon_eks_kube_proxy         = true
  enable_amazon_eks_aws_ebs_csi_driver = true

  # Add-ons
  enable_aws_load_balancer_controller = true
  enable_metrics_server               = true
  enable_cluster_autoscaler           = true
  enable_aws_cloudwatch_metrics       = true
  enable_velero                       = true
  values = [templatefile("${path.module}/values/velero.yaml", {
    bucket_name        = "<YOUR_BUCKET_NAME>",
    bucket_region      = "<YOUR_BUCKET_REGION>"
    snapshot_region    = "<YOUR_SNAPSHOT_REGION>"
    snapshot_altregion = "<YOUR_SNAPSHOT_REGION>"
    cluster_name       = local.cluster_name
    velero_az_override = "<VELERO_AWS_AZ_OVERRIDE>"
  })]
  tags = local.tags
}

#---------------------------------------------------------------
# Supporting Resources
#---------------------------------------------------------------

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 3.0"

  name = local.cluster_name
  cidr = local.vpc_cidr

  azs             = local.availability_zones
  public_subnets  = [for k, v in local.availability_zones : cidrsubnet(local.vpc_cidr, 8, k)]
  private_subnets = [for k, v in local.availability_zones : cidrsubnet(local.vpc_cidr, 8, k + 10)]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  # Manage so we can name
  manage_default_network_acl    = true
  default_network_acl_tags      = { Name = "${local.cluster_name}-default" }
  manage_default_route_table    = true
  default_route_table_tags      = { Name = "${local.cluster_name}-default" }
  manage_default_security_group = true
  default_security_group_tags   = { Name = "${local.cluster_name}-default" }

  public_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = 1
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"             = 1
  }

  tags = local.tags
}
module "iam" {
  depends_on = [module.eks_blueprints]

  source = "./modules/eks-iam-roles"

  cluster_name = local.cluster_name
}

module "external_dns" {
  count      = var.primary_cluster ? 1 : 0
  depends_on = [module.eks_blueprints]
  source     = "./modules/external-dns-eks"

  aws_account_id  = local.aws_account_id
  cluster_name    = local.cluster_name
  oidc_issuer     = module.eks_blueprints.oidc_provider
  route53_zone_id = data.aws_route53_zone.domain.id
}
