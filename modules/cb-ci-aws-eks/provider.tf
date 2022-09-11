provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
  default_tags {
    tags = var.tags
  }
}

provider "kubernetes" {
  host                   = module.eks.k8s_cluster_endpoint
  cluster_ca_certificate = module.eks.k8s_cluster_certificate
  token                  = module.eks.k8s_cluster_token
}

provider "helm" {
  kubernetes {
    host                   = module.eks.k8s_cluster_endpoint
    cluster_ca_certificate = module.eks.k8s_cluster_certificate
    token                  = module.eks.k8s_cluster_token
  }
}
