data "kubernetes_ingress" "cjoc" {
  depends_on = [helm_release.cbci]

  metadata {
    name      = "cjoc"
    namespace = var.namespace
  }
}

locals {
  oc_secret_data = fileexists("${path.module}/values/secrets.yaml") ? yamldecode(file("${path.module}/values/secrets.yaml")) : {}
  protocol       = "https"
  values = yamlencode({
    OperationsCenter = {
      Platform = var.platform
      HostName = var.host_name
      Protocol = local.protocol
      Resources = {
        Limits = {
          Cpu    = var.oc_cpu
          Memory = "${var.oc_memory}G"
        }
        Requests = {
          Cpu    = var.oc_cpu
          Memory = "${var.oc_memory}G"
        }
      }
      CasC = {
        Enabled = true
      }
      ConfigMapName = var.oc_configmap_name
      ContainerEnv = [
        {
          name  = "SECRETS"
          value = "/var/run/secrets/cjoc"
        }
      ]
      ExtraVolumes = [{
        name = "oc-secrets"
        secret = {
          defaultMode = 0400
          secretName  = "oc-secrets"
        }
        },
        {
          name = "mc-casc-bundle"
          configMap = {
            defaultMode = 0400
            name        = "mc-casc-bundle"
          }
      }]
      ExtraVolumeMounts = [{
        name      = "oc-secrets"
        mountPath = "/var/run/secrets/cjoc"
        },
        {
          name      = "mc-casc-bundle"
          mountPath = "/var/jenkins_home/cb-casc-bundles-store/mc"
      }]
      Ingress = {
        Class       = var.ingress_class
        Annotations = var.ingress_annotations
      }
      JavaOpts = "-Dcom.cloudbees.jenkins.cjp.installmanager.CJPPluginManager.enablePluginCatalogInOC=true -Dcom.cloudbees.masterprovisioning.kubernetes.KubernetesMasterProvisioning.deleteClaim=true"
      Annotations = {
        "cluster-autoscaler.kubernetes.io/safe-to-evict" = "false"
      }
    }
    HibernationEnabled = "true"
  })
}

resource "time_sleep" "wait" {
  depends_on = [kubernetes_namespace.this]

  destroy_duration = "2m"
}


resource "kubernetes_namespace" "this" {
  metadata {
    name = var.namespace
  }

  provisioner "local-exec" {
    when    = destroy
    command = "kubectl delete --all pods --grace-period=0 --force --namespace ${self.metadata[0].name}"
  }

}

resource "kubernetes_secret" "secrets" {
  depends_on = [time_sleep.wait]

  metadata {
    name      = "oc-secrets"
    namespace = var.namespace
  }

  data = local.oc_secret_data
}

resource "helm_release" "cbci" {
  depends_on = [helm_release.casc]

  chart      = "cloudbees-core"
  name       = "cloudbees-ci"
  namespace  = var.namespace
  repository = "https://charts.cloudbees.com/public/cloudbees"
  values     = [local.values]
  version    = var.chart_version
  replace    = true
}

resource "helm_release" "casc" {
  depends_on = [kubernetes_secret.secrets]

  name      = "casc"
  chart     = "${path.module}/charts/casc"
  namespace = var.namespace
  values    = [local.values]
  replace   = true
  set {
    name  = "domain"
    value = var.host_name
  }
  set {
    name  = "mcCount"
    value = 5
  }
}


