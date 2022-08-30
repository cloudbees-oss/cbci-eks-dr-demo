# 00 Day - Infra
####################

output "update_kubeconfig_command" {
  value = "aws eks update-kubeconfig --name ${module.eks.cluster_id} --alias ${module.eks.cluster_id} --profile ${var.aws_profile} --region ${var.aws_region}"
}


output "set_kubectl_context_command" {
  value = "kubectl config use-context ${local.cluster_name}"
}
