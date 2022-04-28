#!/usr/bin/bash
set -euo pipefail
# shellcheck source=/dev/null
source /root/demo-scm/demo.profile.sh
setDebugLevel

while aws ec2 describe-snapshots --filters Name=tag-key,Values=velero.io/backup --max-items 250 | jq -r '.Snapshots | .[].State' | grep -F pending
do
    sleep 5
done

# https://velero.io/docs/v1.6/migration-case/ & https://github.com/vmware-tanzu/velero-plugin-for-aws#migrating-pvs-across-clusters
# Also suffices to migrate to a nodegroup in a different AZ:
# https://hodovi.cc/blog/migrating-kubernetes-persistentvolumes-across-regions-azs-aws/

# Make sure the cluster is scaled up. (Otherwise symptom is that ns deletion hangs.)
kubectl top pod
kubectl top node

# https://issues.jenkins.io/browse/JENKINS-67097 workaround:
kubectl delete pod --all --force --ignore-not-found
# Velero does not work to overwrite in place (https://github.com/vmware-tanzu/velero/issues/469). You have to delete everything first:
kubectl delete --ignore-not-found --wait ns cbci
kubectl patch -n velero backupstoragelocation/default --type merge --patch '{"spec":{"accessMode":"ReadOnly"}}'
function bsl_rw {
    kubectl patch -n velero backupstoragelocation/default --type merge --patch '{"spec":{"accessMode":"ReadWrite"}}'
}
trap bsl_rw EXIT
INFO "Velero Restore Process..."
velero restore create --from-schedule cbci-dr
until kubectl get ing -n cbci cjoc
do
    sleep 1
done
INFO "Switching DNS to Failover Region..."
bash "$BIN/switch-dns.sh"
#https://stackoverflow.com/a/55514852
# for pvc in $(kubectl get pvc -n cbci | awk '{ if (NR!=1) { print $1}}'); do
#     kubectl delete pvc "$pvc" -n cbci
# done
# for pv in $(kubectl get pvc -n cbci | awk '{ if (NR!=1) { print $1}}'); do
#     kubectl delete pvc "$pv" -n cbci
# done
until kubectl get sts -n cbci cjoc
do
    sleep 1
done
kubectl rollout status sts/cjoc
