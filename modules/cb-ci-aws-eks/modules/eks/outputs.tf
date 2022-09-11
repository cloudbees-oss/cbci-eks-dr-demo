output "update_kubeconfig_command" {
  value = "aws eks update-kubeconfig --name ${module.eks_blueprints.eks_cluster_id} --alias ${module.eks_blueprints.eks_cluster_id}"
}


output "set_kubectl_context_command" {
  value = "kubectl config use-context ${local.cluster_name}"
}


output "k8s_cluster_endpoint" {
  value = module.eks_blueprints.eks_cluster_endpoint
}

output "k8s_cluster_certificate" {
  value = local.cluster_ca_certificate
}

output "k8s_cluster_token" {
  value = local.cluster_auth_token
}
