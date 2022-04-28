#!/usr/bin/bash
set -euo pipefail
# shellcheck source=/dev/null
source /root/demo-scm/demo.profile.sh
setDebugLevel

INFO "Prerequisite: it might require to scale the cluster at first to hold the workload"
exitingMc=$(helm get values casc | grep mcCount | cut -d":" -f 2 | xargs)
#Deploy only if the MC_COUNT has changed
if [ "$exitingMc" -ne "$MC_COUNT" ]; then
    INFO "Updating the number of Controller from $exitingMc to $MC_COUNT"
    deployCbCi
else
    INFO "Existing Managed Controller ($exitingMc) are the same number as the input Mc Count ($MC_COUNT)"
fi

kubectl delete pod cjoc-0
kubectl rollout status sts cjoc

kubectl top node

for x in $(seq 0 $(( MC_COUNT - 1))); do
    mc=mc$x
    until kubectl get sts "$mc"
    do
        bash "$BIN/cli.sh" "cjoc" managed-master-start "$mc" || INFO "Managed Master $mc does not required to be started"
        sleep 1
    done
    kubectl delete pod "$mc-0" 2> /dev/null || INFO "The Pod $mc-0 is not currently available"
    kubectl rollout status sts "$mc"
    for i in {1..3}; do
        INFO "Launching set of build number $i for $mc jobs"
        bash "$BIN/wake-and-build.sh" "$mc" checkpointed
        bash "$BIN/wake-and-build.sh" "$mc" easily-resumable
        bash "$BIN/wake-and-build.sh" "$mc" uses-agents
    done
    if [ $(( x % 5 )) == 0 ]; then
        setAWSRoleSession
    fi
done

kubectl top node
