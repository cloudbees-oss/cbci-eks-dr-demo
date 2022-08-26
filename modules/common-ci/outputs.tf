# 00 Day - Infra
####################

output "update_kubeconfig_command" {
  value = "aws eks update-kubeconfig --name ${module.eks.cluster_id} --profile ${var.aws_profile} --region ${var.aws_region}"
}

output "update_kubectl_context_command" {
  value = "kubectl config rename-context ${module.eks.cluster_arn} ${local.cluster_name}"
}

output "set_kubectl_context_command" {
  value = "kubectl config use-context ${local.cluster_name}"
}

# 01 Day - Apps
####################

output "ci_namespace" {
  value = var.ci_namespace
}

output "update_kubectl_namespace_command" {

  value = "kubectl config set-context --current --namespace=${var.ci_namespace}"
}

output "ci_url" {
  value =  local.cjoc_url
}