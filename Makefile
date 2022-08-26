# START:=$(shell date +%s)

DEBUG:= true
DEBUG_FILE:=root/terraform.logs

CI_NAMESPACE:="cb-ci"

BACKUP_SQUED_NAME:=cbci-dr
BACKUP_FREQ:=15m
BACKUP_TTL:=1h
BACKUP_EXCLUDE:=pods,events,events.events.k8s.io,targetgroupbindings.elbv2.k8s.aws

#CLUSTER_PFIX:=$(shell terraform -chdir=$(ROOT_COMMON) output --raw cluster_prefix)
CLUSTER_PFIX:=dr-ci-demo
export KUBE_CONFIG_PATH=~/.kube/config

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

define apply_primary
	terraform -chdir=root/ci-$1 plan -out="$1.primary.plan" -var-file=../../env/common.tfvars -var-file=../../env/$1.tfvars -var "primary_cluster=true" -input=false
	terraform -chdir=root/ci-$1 apply "$1.primary.plan"
endef

define clean_cluster
	terraform -chdir=root/ci-$1 plan -out="$2.plan" -var-file=../../env/ci.tfvars -var "deploy_apps=false" -input=false
	terraform -chdir=root/ci-=$1 apply "$2.plan"
endef

define destroy
    terraform -chdir=root/ci-$1 destroy -var-file=../../env/common.tfvars -var-file=../../env/$1.tfvars
endef

define t_init
	terraform -chdir=root/ci-$1 fmt
	terraform -chdir=root/ci-$1 init
	terraform -chdir=root/ci-$1 validate
endef

define clean
	rm $(DEBUG_FILE) 2> /dev/null || echo "There is not debug file"
	rm $1/*.plan 2> /dev/null || echo "There is not plan files in $1"
endef

define setK8sContext
	kubectl config delete-context $(CLUSTER_PFIX)-$1 2> /dev/null || echo "There is not context $(CLUSTER_PFIX)-$1"
	eval $(shell terraform -chdir=root/ci-$1 output update_kubeconfig_command)
	eval $(shell terraform -chdir=root/ci-$1 output update_kubectl_context_command)
endef

define shiftTo
	kubectl config use-context $(CLUSTER_PFIX)-$1 2> /dev/null || echo "There is not context $(CLUSTER_PFIX)-$1 availble yet"
endef

define describe
	$(call title, Terraform Outputs)
	@terraform -chdir=root/ci-$1 output
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

up_ci: _submodule _ci_init_alpha _ci_alpha_primary _ci_import_ctx_alpha _set_backup_schedule _check_availability
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

_check_availability:

	@until kubectl get ing -n $(shell terraform -chdir=root/ci-alpha output --raw ci_namespace) cjoc; do sleep 2 && echo "Waiting for ALB"; done
	@echo "ALB ready"
	@until curl -f $(shell terraform -chdir=root/ci-alpha output ci_url); do sleep 1m && echo "Waiting for Operation Center"; done
	@echo "Operation center ready at $(shell terraform -chdir=root/ci-alpha output --raw ci_url)"

_submodule:

	@git submodule init && git submodule update

_ci_init_alpha:

	$(call title,Initialization of Alpha Resources)
	$(call t_init,alpha)

_ci_alpha_primary:
	
	$(call title,Setting Primary Cluster to Alpha)
	$(call shiftTo,alpha)
	$(call apply_primary,alpha)

_ci_alpha_secondary:

	$(call title,Setting Primary Cluster as beta)
	$(call apply_primary,beta)
	$(call deleteBackupSchedule)

_ci_init_beta:

	$(call title,Initialization of Beta Resources)
	$(call t_init,beta)
	
_ci_beta_primary:

	$(call title,Setting Primary Cluster as beta for Workspace beta)
	$(call shiftTo,beta)
	$(call apply_primary,beta)

_ci_beta_secondary:

	$(call title,Setting Primary Cluster as alpha for Workspace beta)
	$(call shiftTo,beta)
	$(call apply_primary,alpha,ci_beta_secondary)
	$(call deleteBackupSchedule)

_ci_alpha_clean:
	
	$(call title,Cleaning Cluster alpha)
	$(call shiftTo,alpha)
	$(call clean_cluster,alpha,ci_alpha_clean)

_ci_beta_clean:
	
	$(call title,Cleaning Cluster beta)
	$(call shiftTo,beta)
	$(call clean_cluster,beta,ci_beta_clean)

_ci_import_ctx_alpha:

	$(call setK8sContext,alpha)

_ci_import_ctx_beta:

	$(call setK8sContext,beta)

_set_backup_schedule: 

	$(call deleteBackupSchedule)
	velero create schedule $(BACKUP_SQUED_NAME) --schedule='@every $(BACKUP_FREQ)' --ttl $(BACKUP_TTL) --include-namespaces $(shell terraform -chdir=root/ci-alpha output --raw ci_namespace) --exclude-resources $(BACKUP_EXCLUDE)	

_restore:

#Velero does not work to overwrite in place (https://github.com/vmware-tanzu/velero/issues/469). You have to delete everything first:
	kubectl delete --ignore-not-found --wait ns $(shell terraform -chdir=root/ci-alpha output --raw ci_namespace)
	velero restore create --from-schedule $(BACKUP_SQUED_NAME)

_ci_down_alpha:

	$(call title, Destroy Alpha)
	$(call destroy,alpha)

_ci_down_beta:

	$(call title, Destroy Beta)
	$(call destroy,beta)