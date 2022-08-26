jenkins:
  views:
  - masters:
      name: "Controllers"
      jobFilters:
      - "connectedMasterViewFilter"
      recurse: true
      columns:
      - "status"
      - "weather"
      - "jobName"
      - "manageMaster"
      - "masterConfigurationStaleViewColumn"
      - "totalJobsViewColumn"
      - "queueSizeViewColumn"
      - "jenkinsVersionViewColumn"
      - "cascViewColumn"
      - "listSelectionColumn"
  - all:
      name: "all"
unclassified:
# Best-Practice: Use SCM for Managed Master Casc Bundles
# https://docs.cloudbees.com/docs/cloudbees-ci/2.332.3.4/casc-controller/add-bundle#_adding_casc_bundles_from_an_scm_tool
  bundleStorageService:
    activated: true
    activeBundle:
      name: "casc-store"
      retriever:
        SCM:
          scmSource:
            git:
              credentialsId: "GH-token-merck"
              remote: ${CASC_BUNDLE_REPO}
              traits:
              - "gitBranchDiscovery"
  cascAutoControllerProvisioning:
    provisionControllerOnCreation: true
  location:
    url: ${CI_URL}
# Best-Practice: Discard Old Builds
# https://support.cloudbees.com/hc/en-us/articles/215549798
  buildDiscarders:
    configuredBuildDiscarders:
    - "jobBuildDiscarder"
    - simpleBuildDiscarder:
        discarder:
          logRotator:
            numToKeepStr: "3"
  usageStatisticsCloudBees:
    disabledJenkinsUsageStatistics: true
    usageStatisticsCollected: false  
cloudBeesCasCServer:
  defaultBundle: "general"
  visibility: true
# Best-Practice: Enable Beekeeper
# 1.3.4 | Plugin Managent. CAP. Beekeper
beekeeper:
  enabled: true
  securityWarnings:
    enabledForCore: true
    enabledForPlugins: true
  upgrades:
    autoDowngradePlugins: false
    autoUpgradePlugins: true
# 1.3.5 | Operations at Scale. CloudBees Advisor
advisor:
  acceptToS: true
  email: "example.user@mail.com"
  excludedComponents:
  - "AgentsSystemConfiguration"
  - "KubernetesMasterLogs"
  - "AgentsJVMProcessSystemMetricsContents"
  - "GCLogs"
  - "AgentsConfigFile"
  - "ConfigFileComponent"
  - "RootCAs"
  - "SlaveLogs"
  - "OtherConfigFilesComponent"
  - "HeapUsageHistogram"
  - "OtherLogs"
  - "SlaveLaunchLogs"
  nagDisabled: false
# 1.1.3 | Node pools for Kubernetes installation 
masterprovisioning:
  kubernetes:
    yaml: |-
      kind: StatefulSet
      spec:
        template:
          metadata:
            annotations:
              cluster-autoscaler.kubernetes.io/safe-to-evict: "false"
          spec:
            tolerations:
              - key: "dedicated"
                operator: "Equal"
                value: "apps"
                effect: "NoSchedule"