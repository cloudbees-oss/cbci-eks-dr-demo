#!/usr/bin/bash
set -euo pipefail
# shellcheck source=/dev/null
source /root/demo-scm/demo.profile.sh
setDebugLevel

#######################
## Functions
#######################

destroy_snaphots(){
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
}
destroy_apps_region(){
    cd "$HELM_DIR"
    helmfile --file /tmp/hf.east-temp.yaml destroy 2> /dev/null || true
    helmfile --file hf.common.yaml destroy 2> /dev/null || true
    setState "build.${AWS_DEFAULT_REGION}.apps" false
    INFO "Apps destroyed for ${AWS_DEFAULT_REGION}"
}
destroy_apps(){
    (in-east && destroy_apps_region) || INFO "Could not use the east kubernetes context"
    (in-west && destroy_apps_region) || INFO "Could not use the west kubernetes context"
}
destroy_infra(){
    for region in $EAST_REGION $WEST_REGION
    do
        #setAWSRoleSession
        if eksctl get cluster --region "$region" --name "$CLUSTER_NAME" 2> /dev/null; then
            eksctl delete cluster --region "$region" --name "$CLUSTER_NAME"
        else
            INFO "Could not find cluster $CLUSTER_NAME in region $region"
        fi
        for s in $(aws cloudformation list-stacks --region "$WEST_REGION" | jq -r '.[][].StackName' | grep -F "$DEMO_NAME")
        do
            aws cloudformation delete-stack --region "$WEST_REGION" --stack-name "$s"
        done
        setState "build.$region.infra" false
        INFO "Infra destroyed for $region"
    done
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
}
destroy_tmp_artifact(){
    cd "$ROOT"
    rm -rf /tmp/*.*
    ##rm -f demo.state.yaml
    INFO "Demo project artifacts and state deleted"
}

#######################
## Init
#######################

destroy_snaphots
destroy_apps
destroy_infra
destroy_tmp_artifact
