#!/usr/bin/bash
set -euo pipefail
# shellcheck source=/dev/null
source /root/demo-scm/demo.profile.sh
getLocals; setDebugLevel

# Useful when you have a long schedule like
# velero create schedule cbci-dr --schedule='@every 6h' --ttl 12h --include-namespaces cbci --exclude-resources pods,events,events.events.k8s.io
# and you want to manually trigger backups.

export TZ=UTC
velero backup create --from-schedule cbci-dr --wait
