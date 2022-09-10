locals {
  oc_secret_data = fileexists("values/secrets.yaml") ? yamldecode(file("values/secrets.yaml")) : {}

  values = yamlencode({
    OperationsCenter = {
      Platform = var.platform
      HostName = var.host_name
      Protocol = "https"
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
          value = var.secret_mount_path
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

resource "kubernetes_config_map" "casc_bundle" {
  depends_on = [time_sleep.wait]
  for_each   = local.create_bundle ? local.this : []

  metadata {
    name      = var.oc_configmap_name
    namespace = var.namespace
  }

  data = local.oc_bundle_data
}

resource "kubernetes_secret" "secrets" {
  depends_on = [time_sleep.wait]
  for_each   = local.create_secret ? local.this : []

  metadata {
    name      = var.oc_secret_name
    namespace = var.namespace
  }

  data = local.oc_secret_data
}

resource "helm_release" "cbci" {
  depends_on = [time_sleep.wait]

  chart      = "cloudbees-core"
  name       = "cloudbees-ci"
  namespace  = var.namespace
  repository = "https://charts.cloudbees.com/public/cloudbees"
  values     = [local.values]
  version    = var.chart_version
  replace    = true
}

resource "helm_release" "casc" {
  depends_on = [time_sleep.wait]

  chart      = "casc"
  name       = "casc"
  namespace  = var.namespace
  repository = "./casc"
  values     = [local.values]
  version    = var.chart_version
  replace    = true
  set {
    name  = "domain"
    value = var.host_name
  }
  set {
    name  = "mcCount"
    value = 5
  }
}


