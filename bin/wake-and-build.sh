#!/usr/bin/bash
set -euo pipefail
# shellcheck source=/dev/null
source /root/demo-scm/demo.profile.sh
setDebugLevel

if [ $# \!= 2 ]
then
    kubectl get sts | grep -F 0/0
    ERROR   "Usage: bash wake-and-build.sh mc23 uses-agents \n" + \
            "or: for x in {0..99}; do bash wake-and-build.sh mc${x} uses-agents; done"
fi

# Password does not work here because a crumb is then required (CLI works without crumb, but BEE-646 does not support hibernation)
curl -i -XPOST -u admin:"$(kubectl get secret api-token -o jsonpath='{.data.token}' | base64 --decode)" "http://$ROUTE_53_DOMAIN/hibernation/ns/cbci/queue/$1/job/$2/build?delay=180sec"
