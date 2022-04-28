#!/usr/bin/bash
set -euo pipefail
# shellcheck source=/dev/null
source /root/demo-scm/demo.profile.sh
setDebugLevel

#######################
## Functions
#######################

destroy_snaphots(){
    if [ "$(getState "build.backups")" = true ]; then
        for region in $EAST_REGION $WEST_REGION
        do
            while :
            do
            INFO "listing EBS snapshots created by Velero in $region…"
            aws ec2 describe-snapshots --region "$region" --filters Name=tag-key,Values=velero.io/backup --max-items 1000 > /tmp/snapshots.json
            jq -r '.Snapshots[].SnapshotId' < /tmp/snapshots.json | egrep -q . || break
            jq -r '.Snapshots[].SnapshotId' < /tmp/snapshots.json | parallel -P15 --line-buffer "jq -r --arg id {} '.Snapshots[] | select(.SnapshotId == "'$'"id) | .Tags[] | select(.Key == \"velero.io/backup\") | .Value' < /tmp/snapshots.json; aws ec2 delete-snapshot --region $region --snapshot-id {}"
            done
        done
        setState "build.backups" false
        INFO "Backups destroyed" 
    else 
        INFO "There are not backups to destroy"    
    fi
}
destroy_apps(){
    cd "$HELM_DIR"
    for region in $EAST_REGION $WEST_REGION
    do
        export AWS_DEFAULT_REGION=$region
        if [ "$(getState "build.$region.apps")" = true ]; then
            use-context
            helmfile --file /tmp/hf.east-temp.yaml destroy
            helmfile --file hf.common.yaml destroy
            setState "build.$region.apps" false
            INFO "Apps destroyed for $region"
        else 
            INFO "There are not apps to destroy for $region" 
        fi
    done
}
destroy_infra(){
    for region in $EAST_REGION $WEST_REGION
    do
        if [  "$(getState "build.$region.infra")" = true  ]; then
            setAWSRoleSession
            eksctl delete cluster --region "$region" --name "$CLUSTER_NAME"
            for s in $(aws cloudformation list-stacks --region "$WEST_REGION" | jq -r '.[][].StackName' | grep -F "$DEMO_NAME")
            do
                aws cloudformation delete-stack --region "$WEST_REGION" --stack-name "$s"
            done
            setState "build.$region.infra" false
            INFO "Infra destroyed for $region"
        else
            INFO "There is not infra to destroy for $region"
        fi 
    done
    if [  "$(getState "build.global.infra")" = true  ]; then
        aws s3 rm "s3://$DEMO_NAME" --recursive || INFO "No bucket $DEMO_NAME"
        aws s3 rb "s3://$DEMO_NAME" --force || INFO "No bucket $DEMO_NAME"
        arn="arn:aws:iam::$ACCOUNT:policy/$DEMO_NAME-velero"
        if aws iam get-policy --policy-arn "$arn"; then
            # detach all entities before deleting policy
            local policy_entities
            policy_entities=$(aws iam list-entities-for-policy --policy-arn "$arn")
            for policy_role in $(echo "$policy_entities" | jq -r '.PolicyRoles[].RoleName'); do
                aws iam detach-role-policy --role-name "$policy_role" --policy-arn "$arn"
            done
            for policy_user in $(echo "$policy_entities" | jq -r '.PolicyUsers[].UserName'); do
                aws iam detach-user-policy --user-name "$policy_user" --policy-arn "$arn"
            done
            for policy_group in $(echo "$policy_entities" | jq -r '.PolicyGroups[].GroupName'); do
                aws iam detach-group-policy --group-name "$policy_group" --policy-arn "$arn"
            done
            for v in $(aws iam list-policy-versions --policy-arn "$arn" | jq -r '.Versions[]|select(.IsDefaultVersion == false).VersionId')
            do
                aws iam delete-policy-version --policy-arn "$arn" --version-id "$v" || INFO "Default version"
            done
            aws iam delete-policy --policy-arn "$arn"
        fi
        setState "build.global.infra" false
        INFO "Global infra destroyed"
    else 
        INFO "There is not Global infra to destroy"
    fi
}
destroy_tmp_artifact(){
    cd "$ROOT"
    rm -rf /tmp/*.*
    rm -f demo.state.yaml
    INFO "Demo project artifacts and state deleted"
}

#######################
## Init
#######################

destroy_snaphots
#destroy_apps
destroy_infra
destroy_tmp_artifact
