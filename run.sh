#!/usr/bin/bash
set -euo pipefail
# shellcheck source=/dev/null
source /root/demo-scm/demo.profile.sh
setDebugLevel

SECONDS=0

#######################
## Functions
#######################

build(){
    if bash "$BIN/setup.sh"; then
        INFO "$DEMO_NAME - Build OK" 
    else
        ERROR "$DEMO_NAME - Build KO" 
    fi
}

reload-cbci(){
    if bash "$BIN/reload-cbci.sh"; then
        INFO "$DEMO_NAME  - Reload OK"
    else
        ERROR "$DEMO_NAME  - Reload KO"
    fi
}

scale(){
    if bash "$BIN/scale.sh"; then
        INFO "$DEMO_NAME  - Scale OK"
    else
        ERROR "$DEMO_NAME  - Scale KO"
    fi
}

restore(){
    if bash "$BIN/restore.sh"; then
        INFO "$DEMO_NAME  - Restore OK"
    else
        ERROR "$DEMO_NAME  - Restore KO"
    fi
}

destroy(){
    if bash "$BIN/teardown.sh"; then
        INFO "$DEMO_NAME  - Destroy OK"
    else
        ERROR "$DEMO_NAME  - Destroy KO"
    fi
}

#######################
## Init
#######################

cat <<EOF
Select one of the following option and press [ENTER]:

    [B] Build
    [L] reLoad
    [S] Scale
    [R] Restore
    [D] Destroy
EOF
read -r opt
upperOpt=$(echo "$opt" | tr '[:lower:]' '[:upper:]')
if [ ! -d "logs" ]; then
    mkdir "logs"
fi
case $upperOpt in
    [B]* )
        build 2>&1 | tee "logs/build_$DEMO_NAME.log"
        ;;
    [L]* )
        reload-cbci 2>&1 | tee "logs/reload_$DEMO_NAME.log"
        ;;  
    [S]* )
        scale 2>&1 | tee "logs/scale_$DEMO_NAME.log"
        ;;    
    [R]* )
        restore 2>&1 | tee "logs/restore_$DEMO_NAME.log"
        ;;
    [D]* )
        destroy 2>&1 | tee "logs/destroy_$DEMO_NAME.log"
        ;;
    * ) INFO "Please answer a valid option."
        ;;
esac
duration=$SECONDS
INFO "$((duration / 60)) minutes and $((duration % 60)) seconds elapsed."