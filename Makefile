# START:=$(shell date +%s)

INFRA_DIR:=infra/eks/root
APPS_DIR:=apps

DEBUG:= true
DEBUG_FILE:=$(INFRA_DIR)/terraform.logs

BACKUP_SQUED_NAME:=cbci-dr
BACKUP_FREQ:=15m
BACKUP_TTL:=1h
BACKUP_EXCLUDE:=pods,events,events.events.k8s.io,targetgroupbindings.elbv2.k8s.aws

#CLUSTER_PFIX:=$(shell terraform -chdir=$(ROOT_COMMON) output --raw cluster_prefix)
CLUSTER_PFIX:=dr-ci-demo
export KUBE_CONFIG_PATH=~/.kube/config
export HELM_DIR=$(APPS_DIR)

#https://www.terraform.io/internals/debugging
ifeq ($(DEBUG),true)
	export TF_LOG=DEBUG
	export TF_LOG_PATH=$(DEBUG_FILE)
endif

define title
    @echo "===================================="
	@echo "$1"
	@echo "===================================="
endef

define infra_init
	terraform -chdir=$(INFRA_DIR)/$1 fmt
	terraform -chdir=$(INFRA_DIR)/$1 init
	terraform -chdir=$(INFRA_DIR)/$1 validate
endef

define infra_set
	if [ "${2}" = "primary" ]; then terraform -chdir=$(INFRA_DIR)/$1 plan -out="$1.$2.plan" -var-file=../../env/infra-cbci-eks.tfvars -var-file=../../env/$1.tfvars -var "primary_cluster=true" -input=false; else terraform -chdir=$(INFRA_DIR)/$1 plan -out="$1.$2.plan" -var-file=../../env/infra-cbci-eks.tfvars -var-file=../../env/$1.tfvars -var "primary_cluster=false" -input=false; fi
	terraform -chdir=$(INFRA_DIR)/$1 apply "$1.$2.plan"
endef

define infra_destroy
	if [ "${1}" = "common" ]; then terraform -chdir=$(INFRA_DIR)/$1 destroy -var-file=../../env/infra-cbci-eks.tfvars -input=false; else terraform -chdir=$(INFRA_DIR)/$1 destroy -var-file=../../env/infra-cbci-eks.tfvars -var-file=../../env/$1.tfvars -input=false; fi
endef

define clean_cluster
	@#TODO Rewrite this
endef

define clean
	rm $(DEBUG_FILE) 2> /dev/null || echo "There is not debug file"
	rm $1/*.plan 2> /dev/null || echo "There is not plan files in $1"
endef

define setK8sContext
	kubectl config delete-context $(CLUSTER_PFIX)-$1 2> /dev/null || echo "There is not context $(CLUSTER_PFIX)-$1"
	eval $(shell terraform -chdir=$(INFRA_DIR)/ci-$1 output update_kubeconfig_command)
endef

define shiftTo
	kubectl config use-context $(CLUSTER_PFIX)-$1 2> /dev/null || echo "There is not context $(CLUSTER_PFIX)-$1 availble yet"
endef

define describe
	$(call title, Terraform Outputs)
	@terraform -chdir=$(INFRA_DIR)/$1 output
	$(call title, K8s resources)
	@kubectl get all -A
	$(call title, Velero)
	@velero schedule get
	@velero backup get
endef

define deleteBackupSchedule
	velero schedule delete $(BACKUP_SQUED_NAME) --confirm
endef

###########################
## Public targets
###########################

default:
	@echo "Infrastructure and Application Deployment based on Terraform system from a templates files."
	@echo "The following commands are available:"
	@echo " - up_ci          	 : Deploy the CloudBees CI on Modern infrastructure in the Alpha Cluster"
	@echo " - up_ci_dr           : Deploy the CloudBees CI on Modern infrastructure in the Alpha Cluster and ready for shifting to the Beta Cluster in case of DR"
	@echo " - watch_alpha        : Describe current state of the Alpha Cluster"
	@echo " - watch_beta_dr      : Describe current state of the Beta Cluster"
	@echo " - trigger_backup	 : Trigger a manual backup from the predefined Velero schedule $(BACKUP_SQUED_NAME). It needs to be placed in primary region"
	@echo " - failover2beta_dr	 : Failover of CI to the Beta to become Primary Cluster"
	@echo " - failover2alpha_dr	 : Failover of CI to the Alpha to become Primary Cluster"
	@echo " - down_ci            : Destroy the cluster Alpha"
	@echo " - down_ci_dr         : Destroy the cluster Alpha and Beta"

trigger_backup:

	@velero backup create --from-schedule $(BACKUP_SQUED_NAME) --wait

watch_alpha: 

	$(call title,Alpha)
	$(call shiftTo,alpha)
	$(call describe)

watch_beta_dr: 

	$(call title,Beta)
	$(call shiftTo,beta)
	$(call describe)

#up_ci: _ci_init_alpha _ci_alpha_primary _ci_import_ctx_alpha _set_backup_schedule _check_availability
up_ci: _common_init_and_apply _ci_init_alpha _ci_alpha_primary _ci_import_ctx_alpha
up_ci_dr: up_ci _ci_init_beta _ci_beta_secondary _ci_import_ctx_beta
failover2beta_dr: _ci_alpha_secondary _ci_beta_primary _restore _set_backup_schedule _check_availability
failover2alpha_dr: _ci_beta_secondary _ci_alpha_primary _restore _set_backup_schedule _check_availability
clean_infra: _ci_alpha_clean
clean_infra_dr: _ci_alpha_clean _ci_beta_clean
down_ci: _ci_down_alpha 
down_ci_dr: _ci_down_beta _ci_down_alpha

###########################
## Private targets
###########################

# _elapsed_time:
# 	https://www.baeldung.com/linux/bash-calculate-time-elapsed
#   END=$(shell date +%s)
# 	echo "Elapsed Time: $(($(END)-$(START))) seconds"


_apps_primary:

	helmfile --debug --file $(APPS_DIR) apply

_check_availability:

	@until kubectl get ing -n $(shell terraform -chdir=$(INFRA_DIR)/ci-alpha output --raw ci_namespace) cjoc; do sleep 2 && echo "Waiting for ALB"; done
	@echo "ALB ready"
	@until curl -f $(shell terraform -chdir=$(INFRA_DIR)/ci-alpha output ci_url); do sleep 1m && echo "Waiting for Operation Center"; done
	@echo "Operation center ready at $(shell terraform -chdir=$(INFRA_DIR)/ci-alpha output --raw ci_url)"

_common_init_and_apply:

	$(call title,Building Common infra)
	$(call infra_init,common)
	$(call clean,common)
	terraform -chdir=$(INFRA_DIR)/common plan -out="common.plan" -var-file=../../env/infra-cbci-eks.tfvars -var-file=../../env/ci-beta.tfvars -input=false
	terraform -chdir=$(INFRA_DIR)/common apply "common.plan"

_ci_init_alpha:

	$(call title,Initialization of Alpha Resources)
	$(call infra_init,ci-alpha)

_ci_alpha_primary:
	
	$(call title,Setting Primary Cluster to Alpha)
	$(call clean,ci-alpha)
	$(call infra_set,ci-alpha,primary)

_ci_alpha_secondary:

	$(call title,Setting Primary Cluster as beta)
	$(call clean,ci-alpha)
	$(call infra_set,ci-alpha,secondary)
	$(call deleteBackupSchedule)

_ci_init_beta:

	$(call title,Initialization of Beta Resources)
	$(call infra_init,ci-beta)
	
_ci_beta_primary:

	$(call title,Setting Primary Cluster as beta for Workspace beta)
	$(call clean,ci-beta)
	$(call infra_set,ci-beta,primary)

_ci_beta_secondary:

	$(call title,Setting Secondary Cluster to Beta)
	$(call clean,ci-beta)
	$(call infra_set,ci-beta,secondary)
	$(call deleteBackupSchedule)

_ci_alpha_clean:
	
	$(call title,Cleaning Cluster alpha)
	$(call clean_cluster,alpha,ci_alpha_clean)

_ci_beta_clean:
	
	$(call title,Cleaning Cluster beta)
	$(call clean_cluster,beta,ci_beta_clean)

_ci_import_ctx_alpha:

	$(call setK8sContext,alpha)

_ci_import_ctx_beta:

	$(call setK8sContext,beta)

_set_backup_schedule: 

	$(call deleteBackupSchedule)
	velero create schedule $(BACKUP_SQUED_NAME) --schedule='@every $(BACKUP_FREQ)' --ttl $(BACKUP_TTL) --include-namespaces $(shell terraform -chdir=$(INFRA_DIR)/ci-alpha output --raw ci_namespace) --exclude-resources $(BACKUP_EXCLUDE)	

_restore:

#Velero does not work to overwrite in place (https://github.com/vmware-tanzu/velero/issues/469). You have to delete everything first:
	kubectl delete --ignore-not-found --wait ns $(shell terraform -chdir=root/ci-alpha output --raw ci_namespace)
	velero restore create --from-schedule $(BACKUP_SQUED_NAME)

_ci_down_alpha:

	$(call title, Destroy Alpha)
	$(call infra_destroy,ci-alpha)

_ci_down_beta:

	$(call title, Destroy Beta)
	$(call infra_destroy,ci-beta)

_common_down:

	$(call title, Destroy Common)
	$(call infra_destroy,common)

