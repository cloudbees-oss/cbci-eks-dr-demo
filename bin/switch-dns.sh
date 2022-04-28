#!/usr/bin/bash
set -euo pipefail
# shellcheck source=/dev/null
source /root/demo-scm/demo.profile.sh
setDebugLevel

use-context

# TODO consider using https://github.com/kubernetes-sigs/external-dns/blob/master/docs/tutorials/aws.md instead
# also consider enabling TLS: https://aws.amazon.com/certificate-manager/

elb=
while :
do
    elb=$(kubectl get ing -n cbci cjoc -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
    if [ -z "$elb" ]
    then
        INFO "waiting for ingress to be ready"
        sleep 3
    else
        break
    fi
done
hzi=$(aws --region "$AWS_DEFAULT_REGION" elb describe-load-balancers | jq -r --arg elb "$elb" '.LoadBalancerDescriptions | .[] | select(.DNSName == $elb) | .CanonicalHostedZoneNameID')
aws route53 change-resource-record-sets --hosted-zone-id "$ROUTE_53_ZONE_ID" --change-batch "$(jq -nc --arg domain "$ROUTE_53_DOMAIN" --arg elb "$elb" --arg hzi "$hzi" '{Changes: [{Action: "UPSERT", ResourceRecordSet: {Name: ($domain + "."), Type: "A", AliasTarget: {DNSName: ("dualstack." + $elb + "."), EvaluateTargetHealth: true, HostedZoneId: $hzi}}}]}')"

INFO 'Tip: chrome://net-internals/#dns & chrome://net-internals/#sockets'
INFO "alternately: firefox http://$ROUTE_53_DOMAIN/"
INFO "on Ubuntu you may also need: sudo systemd-resolve --flush-caches"
