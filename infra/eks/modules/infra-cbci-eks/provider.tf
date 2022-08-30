provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
  default_tags {
    tags = var.tags
  }
}

provider "kubernetes" {
  host                   = local.cluster_endpoint
  cluster_ca_certificate = local.cluster_ca_certificate
  token                  = local.cluster_auth_token
}

provider "helm" {
  kubernetes {
    host                   = local.cluster_endpoint
    cluster_ca_certificate = local.cluster_ca_certificate
    token                  = local.cluster_auth_token
  }
}

# https://github.com/terraform-aws-modules/terraform-aws-eks/issues/1234
# provider "helm" {
#   kubernetes {
#     config_path = "~/.kube/config"
#   }
# }
# provider "kubectl" {
#   kubernetes {
#     config_path = "~/.kube/config"
#   }
# }
