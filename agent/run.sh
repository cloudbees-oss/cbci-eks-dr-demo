#!/usr/bin/env bash

cd "$(cd "$(dirname "${BASH_SOURCE[0]}")" > /dev/null && pwd)" || return

AGENT="dr-agent"

docker-clean(){
    docker container prune --force
    docker volume prune --force
    docker system prune -a --force
}
docker-agent-buildAndRun(){
    docker build . -t "$AGENT"
    docker container rm "$AGENT" 2> /dev/null || echo "Container $AGENT does not exist"
    cd ..
    docker run --name "$AGENT" -it \
            --mount type=bind,source="$(pwd)",target=/root/demo-scm \
            --mount type=bind,source="$HOME/.aws",target=/root/.aws \
            -v "$(pwd)"/agent/v_kube:/root/.kube/ \
            -v "$(pwd)"/agent/v_tmp:/tmp/ \
            "$AGENT" bash
}
#docker-clean
docker-agent-buildAndRun