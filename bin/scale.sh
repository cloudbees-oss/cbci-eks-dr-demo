#!/usr/bin/bash
set -euo pipefail
# shellcheck source=/dev/null
source /root/demo-scm/demo.profile.sh
setDebugLevel


for region in $EAST_REGION $WEST_REGION
do
    exitingNodes=$(aws eks describe-nodegroup --cluster="$CLUSTER_NAME" --nodegroup-name=ng-linux --region="$region" | jq -r .nodegroup.scalingConfig.desiredSize)
    if [ "$exitingNodes" -ne "$SCALE" ]; then
        INFO "Scaling from $exitingNodes to $SCALE in $region"
        export AWS_DEFAULT_REGION=$region && use-context
        if [ "$SCALE" -eq "0" ]
        then
            kubectl get sts -o name | xargs --no-run-if-empty kubectl scale --replicas=0
            # https://issues.jenkins.io/browse/JENKINS-67097 workaround:
            kubectl delete pod --all --force
        fi
        #setAWSRoleSession
        eksctl scale nodegroup --cluster="$CLUSTER_NAME" --name=ng-linux --nodes=$SCALE --region="$AWS_DEFAULT_REGION"
        until [ "$(kubectl get nodes | grep -c 'Ready')" -eq "$SCALE" ]
        do
            INFO 'Waiting for scale up/down…'
            sleep 5
        done
        eksctl get nodegroup --cluster="$CLUSTER_NAME" 
        kubectl get nodes
        kubectl describe node | grep -F topology.kubernetes.io/zone | sort | uniq -c
        if [ "$SCALE" -ne "0" ]
        then
            until kubectl top node
            do
                INFO 'Waiting for metrics…'
                sleep 5
            done
        fi  
    else
        INFO "Existing Nodes - $exitingNodes - are the same number as the input Scale - $SCALE in $region"
    fi
done