output "update_kubeconfig_command" {
  value = "${module.eks.update_kubeconfig_command} --profile ${var.aws_profile} --region ${var.aws_region}"
}

output "set_kubectl_context_command" {
  value = module.eks.set_kubectl_context_command
}
