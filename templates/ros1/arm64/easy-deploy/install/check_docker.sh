#!/usr/bin/env bash
SCRIPT_NAME=$(basename ${BASH_SOURCE[0]})
source ../utils/bash_utils.sh

# docker 
if CMD=$(docker --version) ; then 
    f_echo_magenta "[${SCRIPT_NAME}] Docker check: ${CMD}"
else
    f_echo_red "[${SCRIPT_NAME}] Docker check failed"
    exit 1
fi
# docker-compose
if CMD=$(docker-compose --version) ; then 
    f_echo_magenta "[${SCRIPT_NAME}] Docker-compose check: ${CMD}"
else
    f_echo_red "[${SCRIPT_NAME}] Docker-compose check failed"
    exit 1
fi
# docker permission
if CMD=$(docker image ls) ; then 
    f_echo_magenta "[${SCRIPT_NAME}] Docker permission check: passed"
else
    f_echo_red "[${SCRIPT_NAME}] Docker permission check failed"
    exit 1
fi