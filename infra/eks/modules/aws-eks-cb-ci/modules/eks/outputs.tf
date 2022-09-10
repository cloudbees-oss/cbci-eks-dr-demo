# 00 Day - Infra
####################

output "update_kubeconfig_command" {
  value = "aws eks update-kubeconfig --name ${module.eks_blueprints.eks_cluster_id} --alias ${module.eks_blueprints.eks_cluster_id}"
}


output "set_kubectl_context_command" {
  value = "kubectl config use-context ${local.cluster_name}"
}
