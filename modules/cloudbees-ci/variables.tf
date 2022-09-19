#https://artifacthub.io/packages/helm/cloudbees/cloudbees-core
variable "chart_version" {}

variable "host_name" {}

variable "ingress_annotations" {}
variable "ingress_class" {}
variable "namespace" {
  default = "cbci"
}

variable "oc_configmap_name" {
  default = "oc-casc-bundle"
}

variable "oc_cpu" {
  default = 2
  type    = number
}

variable "oc_image" {
  default = ""
}

variable "oc_memory" {
  default = 4
  type    = number
}

variable "platform" {
  default = "standard"
}
