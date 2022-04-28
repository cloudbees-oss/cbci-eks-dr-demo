#!/usr/bin/bash
set -euo pipefail
# shellcheck source=/dev/null
source /root/demo-scm/demo.profile.sh
setDebugLevel

if [ $# = 0 ]
then
    ERROR "Usage: bash cli.sh cjoc help"
fi
sts=$1
shift

if [ \! -f /tmp/jenkins-cli.jar ]
then
    curl -o /tmp/jenkins-cli.jar "http://$ROUTE_53_DOMAIN/cjoc/jnlpJars/jenkins-cli.jar"
fi

java -jar /tmp/jenkins-cli.jar -s "http://$ROUTE_53_DOMAIN/$sts/" -auth admin:"$(kubectl get secret login -o jsonpath='{.data.password}' | base64 --decode)" -webSocket "$@"
