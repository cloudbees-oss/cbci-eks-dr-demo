# 00 Day - Infra
####################

output "update_kubeconfig_command" {
  value = module.ci_common.update_kubeconfig_command
}

output "set_kubectl_context_command" {
  value = module.ci_common.set_kubectl_context_command
}
