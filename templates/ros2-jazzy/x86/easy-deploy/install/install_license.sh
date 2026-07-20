#!/usr/bin/env bash
SCRIPT_DIR=$(cd $(dirname ${BASH_SOURCE[0]}) && pwd)
SCRIPT_NAME=$(basename ${BASH_SOURCE[0]})
source ../utils/bash_utils.sh

# install hasp and trial license
f_echo_magenta "[${SCRIPT_NAME}] Installing hasp and trial license..."
cd ../files/license && sudo ./dinst 

# generate c2v
C2V_FILE=hasp_34404.c2v
f_echo_magenta "[${SCRIPT_NAME}] Generating c2v file: ${C2V_FILE}"
cd $SCRIPT_DIR
cd ../files/catkin_ws/movel_ai/license \
    && ./hasp_update_34404 f $C2V_FILE \
    && ./hasp_update_34404 f $C2V_FILE   # need to run twice for AdminMode (due to some unknown hasp bug)
