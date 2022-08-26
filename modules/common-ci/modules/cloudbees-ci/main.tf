data "kubernetes_ingress" "cjoc" {
  depends_on = [helm_release.this]

  metadata {
    name      = "cjoc"
    namespace = var.namespace
  }
}

locals {
  create_bundle = length(var.bundle_data) != 0
  create_secret = length(var.secret_data) != 0

  bundle = concat([for values in [local.bundle_values] : local.bundle_values if local.create_bundle], [""])[0]
  bundle_values = yamlencode({
    OperationsCenter = {
      CasC = {
        Enabled = true
      }

      ConfigMapName = var.oc_configmap_name
    }
  })

  secrets = concat([for values in [local.secret_values] : local.secret_values if local.create_secret], [""])[0]
  secret_values = yamlencode({
    OperationsCenter = {
      ContainerEnv = [
        {
          name  = "SECRETS"
          value = var.secret_mount_path
        }
      ]

      ExtraVolumes = [{
        name = var.oc_secret_name
        secret = {
          defaultMode = 0400
          secretName  = var.oc_secret_name
        }
      }]

      ExtraVolumeMounts = [{
        name      = var.oc_secret_name
        mountPath = var.secret_mount_path
      }]
    }
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

resource "kubernetes_persistent_volume_claim" "maven_cache" {
  metadata {
    # To be used by the submodules Controllers CasC Bundle
    name      = "jenkins-agents-maven-cache"
    namespace = var.namespace
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "8Gi"
      }
    }
  }
  # It will be used by ephemeral Jenkins agents to store Maven artifacts.  
  wait_until_bound = false
}

resource "helm_release" "this" {
  depends_on = [time_sleep.wait]

  chart      = "cloudbees-core"
  name       = "cloudbees-ci"
  namespace  = var.namespace
  repository = var.chart_repository
  values     = [local.values, local.secrets, local.bundle]
  version    = var.chart_version
  replace    = true

  # Dynamically set values if the associated vars are set
  dynamic "set" {
    for_each = local.dynamic_values
    content {
      name  = set.key
      value = set.value
    }
  }
}

resource "kubernetes_config_map" "casc_bundle" {
  depends_on = [time_sleep.wait]
  for_each   = local.create_bundle ? local.this : []

  metadata {
    name      = var.oc_configmap_name
    namespace = var.namespace
  }

  data = var.bundle_data
}

resource "kubernetes_secret" "secrets" {
  depends_on = [time_sleep.wait]
  for_each   = local.create_secret ? local.this : []

  metadata {
    name      = var.oc_secret_name
    namespace = var.namespace
  }

  data = var.secret_data
}

locals {
  dynamic_values = { for k, v in local.optional_values : k => v if v != "" }
  optional_values = {
    "OperationsCenter.Image.dockerImage" = var.oc_image
    "Master.Image.dockerImage"           = var.controller_image
    "Agents.Image.dockerImage"           = var.agent_image
    "Persistence.StorageClass"           = var.storage_class
  }

  this = toset(["this"])

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

      Ingress = {
        Class       = var.ingress_class
        Annotations = var.ingress_annotations
      }

      JavaOpts = "-Xms${var.oc_memory / 2}g -Xmx${var.oc_memory / 2}g -Dcom.cloudbees.jenkins.cjp.installmanager.CJPPluginManager.enablePluginCatalogInOC=true -Dcom.cloudbees.masterprovisioning.kubernetes.KubernetesMasterProvisioning.deleteClaim=true"

      # 1.1.3 | Node pools for Kubernetes installation 

      Tolerations = [{
        key      = "dedicated"
        operator = "Equal"
        value    = "apps"
        effect   = "NoSchedule"
      }]

      Annotations = {
        "cluster-autoscaler.kubernetes.io/safe-to-evict" = "false"
      }

      ExtraGroovyConfiguration = var.extra_groovy_configuration

    }

    HibernationEnabled = var.hibernation_enabled
  })
}
