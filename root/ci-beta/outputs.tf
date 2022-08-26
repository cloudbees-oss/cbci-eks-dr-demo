# 00 Day - Infra
####################

output "update_kubeconfig_command" {
  value = module.ci_common.update_kubeconfig_command
}

output "update_kubectl_context_command" {
  value = module.ci_common.update_kubectl_context_command
}

output "set_kubectl_context_command" {
  value = module.ci_common.set_kubectl_context_command
}

# 01 Day - Apps
####################

output "ci_namespace" {
  value = module.ci_common.ci_namespace
}

output "update_kubectl_namespace_command" {

  value = module.ci_common.update_kubeconfig_command
}

output "ci_url" {
  value = module.ci_common.ci_url
}
