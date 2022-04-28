#!/usr/bin/bash
set -euo pipefail
# shellcheck source=/dev/null
source /root/demo-scm/demo.profile.sh
setDebugLevel

#######################
## Functions
#######################

deploy_infra() {
    cd "$INFRA_DIR"
    if [ "$(getState "build.global.infra")" = false ]; then
            aws s3api create-bucket --bucket "$DEMO_NAME" --region "$WEST_REGION" --create-bucket-configuration LocationConstraint="$WEST_REGION"
            sed "s/@NAME@/$DEMO_NAME/g" < policy.json > "/tmp/$DEMO_NAME-policy.json"
            aws iam delete-policy --policy-arn "arn:aws:iam::$ACCOUNT:policy/$DEMO_NAME-velero" || 
            aws iam create-policy --policy-name "$DEMO_NAME-velero" --policy-document "file:///tmp/$DEMO_NAME-policy.json"
            setState "build.global.infra" true
    else 
        INFO "Using existing global infra"    
    fi
    if [ "$(getState "build.$AWS_DEFAULT_REGION.infra")" = false ]; then
        sed "s/@NAME@/$DEMO_NAME/g; s/@REGION@/$AWS_DEFAULT_REGION/g; s/@ACCOUNT@/$ACCOUNT/g; s/@ZONE1@/$ZONE1/g; s/@ZONE2@/$ZONE2/g; s/@SUFFIX@/$SUFFIX/g" < cluster.yaml > "/tmp/$CLUSTER_NAME-cluster.yaml"
        eksctl create cluster -f "/tmp/$CLUSTER_NAME-cluster.yaml"
        #It should match with use-context demo.profile.sh
        kubectl config rename-context "AWSCLI-Session@${CLUSTER_NAME}.${AWS_DEFAULT_REGION}.eksctl.io" "$CLUSTER_NAME-$AWS_DEFAULT_REGION"
        INFO "Checking Deployed Nodes"
        kubectl get nodes
        setState "build.$AWS_DEFAULT_REGION.infra" true
        INFO "New infra deployed for $AWS_DEFAULT_REGION"
    else 
        INFO "Using existing infra $AWS_DEFAULT_REGION"    
    fi 
}
deploy_apps(){
    cd "$HELM_DIR"
    if [ "$(getState "build.$AWS_DEFAULT_REGION.apps")" = false ]; then
        use-context
        sed "s/@NAME@/$DEMO_NAME/g; s/@REGION@/$AWS_DEFAULT_REGION/g; s/@EAST_REGION@/$EAST_REGION/g; s/@WEST_REGION@/$WEST_REGION/g; s/@ZONE@/$ZONE1/g" < velero.yaml > "/tmp/velero.yaml"
        helmfile --file hf.common.yaml apply
        #workaround https://stackoverflow.com/a/63021823
        kubectl delete -A ValidatingWebhookConfiguration ingress-ingress-nginx-admission -n ingress 2> /dev/null || INFO "Webhook ingress-ingress-nginx-admission already deleted"
        if [ "$AWS_DEFAULT_REGION" == "$EAST_REGION" ]; then
            INFO "Deploying Apps for Primary Region"
            deployCbCi
            bash "$BIN/switch-dns.sh"
        fi
        INFO "Checking Deployed Resources"
        kubectl get all -A -o wide
        INFO "Checking Metrics for Nodes"
        kubectl top nodes
        setState "build.$AWS_DEFAULT_REGION.apps" true
        INFO "New set of apps deployed for $AWS_DEFAULT_REGION" 
    else
        INFO "Using existing set of apps for $AWS_DEFAULT_REGION"    
    fi
}
setBackUpScheduller(){
    if [ "$(getState "build.backups")" = false ] && ! velero get schedule cbci-dr &>/dev/null; then
        in-east
        INFO "Prepare Velero Scheduller. As desired you can also manually schedule: TZ=UTC velero backup create --from-schedule cbci-dr"
        velero create schedule cbci-dr --schedule='@every 15m' --ttl 1h --include-namespaces cbci --exclude-resources pods,events,events.events.k8s.io
        INFO 'Watch Velero progress live:'
        INFO 'while :; do kubectl logs -n velero -f deploy/velero || sleep 1; done'
        setState "build.backups" true
    else
        INFO "Using existing Velero Scheduller"
    fi
}

#######################
## Init
#######################

for region in $EAST_REGION $WEST_REGION
do
    INFO "-------------------------------"
    INFO "Starting Building Phase for Region $region"
    INFO "-------------------------------"
    export AWS_DEFAULT_REGION=$region
    if [ "$AWS_DEFAULT_REGION" = "$EAST_REGION" ]
    then
        #https://github.com/weaveworks/eksctl/issues/3816 us-east-1c never works
        ZONE1=${AWS_DEFAULT_REGION}a
        ZONE2=${AWS_DEFAULT_REGION}b
    else
        #https://docs.aws.amazon.com/vpc/latest/userguide/nat-gateway-troubleshooting.html#nat-gateway-troubleshooting-unsupported-az us-west-1a does not work?
        ZONE1=${AWS_DEFAULT_REGION}b
        ZONE2=${AWS_DEFAULT_REGION}a
    fi
    setAWSRoleSession
    deploy_infra
    setAWSRoleSession
    deploy_apps
done
INFO "-------------------------------"
INFO "Starting Post Building Phase"
INFO "-------------------------------"
setBackUpScheduller
pass=$(kubectl get secret login -o jsonpath='{.data.password}' | base64 --decode)
setState "cjoc.pass" "$pass"
INFO "Login for the first time and generate a Trial License"
INFO "Log in as admin using password $pass at http://$ROUTE_53_DOMAIN/cjoc/ and get a trial license"
until curl -f "http://$ROUTE_53_DOMAIN/cjoc/whoAmI/api/json"
do
    sleep 1m
done
INFO "Preparing Jenkins Token for Remote authentication"
#https://github.com/jenkinsci/configuration-as-code-plugin/issues/1830 hard to make a crumb
crumb=$(curl -s -u admin:$pass -c /tmp/cookies http://$ROUTE_53_DOMAIN/cjoc/crumbIssuer/api/xml'?xpath=concat(//crumbRequestField,":",//crumb)')
token=$(curl -s -u admin:$pass -H $crumb -d newTokenName=general -b /tmp/cookies http://$ROUTE_53_DOMAIN/cjoc/user/admin/descriptorByName/jenkins.security.ApiTokenProperty/generateNewToken | jq -r .data.tokenValue)
kubectl create secret generic api-token --from-literal=token="$token" --namespace cbci
