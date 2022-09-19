locals {
  cjoc_rules = data.kubernetes_ingress.cjoc.spec != null ? data.kubernetes_ingress.cjoc.spec[0].rule : []
  cjoc_host  = data.kubernetes_ingress.cjoc.spec != null ? local.cjoc_rules["host"] : ""
  cjoc_path  = data.kubernetes_ingress.cjoc.spec != null ? [for rule in local.cjoc_rules["http"][0]["path"] : rule["path"] if rule["backend"][0]["service_name"] == "cjoc"][0] : ""
}

output "cjoc_url" {
  value = "${local.protocol}://${local.cjoc_host}${local.cjoc_path}"
}