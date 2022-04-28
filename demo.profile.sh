#!/usr/bin/bash

#######################
## Variables
#######################

export AWS_PROFILE="example-profile" # https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-profiles.html
export AWS_ASSUME_ROLE="example-rol" # Optional (Set it to null in case you work with user credentials)
export ROUTE_53_DOMAIN="dr.example.com"
export ROUTE_53_ZONE_ID="Z041787_EXAMPLE"
export MY_DEMO_ID="ex"
## For concreteness, will refer to these as east and west, though in principle could be any two regions:
export EAST_REGION=us-east-1
export WEST_REGION=us-west-1
## Number of ManagedMaster. Start with a small number. Optionally, you can increase it
export MC_COUNT=5
## Number of Nodes to Scale | Check max and min from infra/cluster.yaml
export SCALE=20
## Debugging
export DEBUG=${DEBUG:-false}

#######################
## Functions
#######################

setState(){
    yq w -i "$ROOT/demo.state.yaml" "$1" "$2"
}

getState(){
    local value=""
    value=$(yq r "$ROOT/demo.state.yaml" "$1")
    echo "$value"
}

#https://docs.aws.amazon.com/STS/latest/APIReference/API_AssumeRole.html
#https://aws.amazon.com/premiumsupport/knowledge-center/iam-assume-role-cli/
#Required for short-lived token Rol assumptions
setAWSRoleSession(){
    if [ -n "$AWS_ASSUME_ROLE" ]; then
        local arn="$(aws iam list-roles --query "Roles[?RoleName == '$AWS_ASSUME_ROLE'].[RoleName, Arn]" | jq -r '.[][]' | grep arn)"
        local assume_creds=$(aws sts assume-role --role-arn "$arn" --role-session-name AWSCLI-Session)
        export AWS_ACCESS_KEY_ID="$(echo "$assume_creds" | jq -r '.Credentials.AccessKeyId')"
        export AWS_SECRET_ACCESS_KEY="$(echo "$assume_creds" | jq -r '.Credentials.SecretAccessKey')"
        export AWS_SESSION_TOKEN="$(echo "$assume_creds" | jq -r '.Credentials.SessionToken')"
        setState aws.expiration "$(echo "$assume_creds" | jq -r '.Credentials.Expiration')"
    else
        setState aws.expiration null
    fi
}

getLocals(){
    local demo
    local suffix
    ## Structure
    export ROOT="/root/demo-scm"
    export INFRA_DIR="$ROOT/infra"
    export HELM_DIR="$ROOT/helm"
    export BIN="$ROOT/bin"
    ## CloudBees CI version: 2.332.2.6
    export CBCI_VERSION=3.42.6+c9672cd0453e
    if [ ! -f "$ROOT/demo.state.yaml" ]; then
        cat <<EOF > "$ROOT/demo.state.yaml"
---
aws:
    # UTC | null = Rol assumption not required
    expiration: null
demo:
    name:
    # https://github.com/weaveworks/eksctl/issues/1386 workaround
    suffix:
# Creation process state
build:
    global:
        infra: false
    # Principal Region (aka East)
    ${EAST_REGION}:
        infra: false
        apps: false
    # Failover Region (aka West)
    ${WEST_REGION}:
        infra: false
        apps: false
    backups: false
cjoc:
    # User admin per OC Casc bundle
    url:
    pass:
EOF
        demo="cbci-dr-$MY_DEMO_ID-$RANDOM"
        suffix="$RANDOM"
        setState demo.name $demo
        setState demo.suffix $suffix
        setState cjoc.url "http://$ROUTE_53_DOMAIN/cjoc"
    else
        demo="$(getState demo.name)"
        suffix="$(getState demo.suffix)"
    fi
    export DEMO_NAME="$demo"
    export SUFFIX="$suffix"
    export CLUSTER_NAME="$demo-$suffix"
    ## AWS
    account=$(aws sts get-caller-identity | jq -r .Account)
    export ACCOUNT="$account"
    setAWSRoleSession
}

in-east() {
    export AWS_DEFAULT_REGION=$EAST_REGION
    use-context
}

in-west() {
    export AWS_DEFAULT_REGION=$WEST_REGION
    use-context
}

use-context() {
    if [ -n "${AWS_DEFAULT_REGION:-}" ]; then
        context="$CLUSTER_NAME-$AWS_DEFAULT_REGION"
        local ns="cbci"
        kubectl config use-context "$context" || ERROR "There is not context $context"
        if [ "$(kubectl get ns $ns 2> /dev/null | grep -c $ns)" -eq "1" ]; then
            kubectl config set-context --current --namespace=$ns
        fi
    else
        ERROR "AWS_DEFAULT_REGION is required. Run in-east or in-west"
    fi
}

deployCbCi(){
    cd "$HELM_DIR" || ERROR "Directory $HELM_DIR is missing"
    sed "s/@ROUTE_53_DOMAIN@/$ROUTE_53_DOMAIN/g" < "cbci.yaml" > "/tmp/cbci-temp.yaml"
    sed "s/@ROUTE_53_DOMAIN@/$ROUTE_53_DOMAIN/g; s/@CB_CI_VERSION@/$CBCI_VERSION/g; s/@MC_COUNT@/$MC_COUNT/g" < "hf.east.yaml" > "/tmp/hf.east-temp.yaml"
    helmfile --file /tmp/hf.east-temp.yaml apply
    INFO "Watch cjoc progress live: kubectl logs -f cjoc-0 -n cbci"
}

setDebugLevel(){
    if [ "$DEBUG" = true ]; then
        shopt -s expand_aliases
        set -x # bash
        alias helm="helm --debug"
        alias helmfile="helmfile --debug"
        alias eksctl="eksctl --verbose 5"
        alias aws="aws --debug"
    fi
}

INFO(){
    local function_name="${FUNCNAME[1]}"
    local msg="$1"
    timeAndDate=$(date)
    echo "[$timeAndDate] [INFO] [${0}] [$function_name] $msg"
}

ERROR(){
    local function_name="${FUNCNAME[1]}"
    local msg="$1"
    timeAndDate=$(date)
    echo "[$timeAndDate] [ERROR] [${0}] [$function_name] $msg"
    exit 1
}

#######################
## Init
#######################

getLocals
