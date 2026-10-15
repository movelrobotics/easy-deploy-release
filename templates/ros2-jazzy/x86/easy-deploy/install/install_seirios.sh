#!/usr/bin/env bash
SCRIPT_NAME=$(basename ${BASH_SOURCE[0]})
source ../utils/bash_utils.sh

# load docker images
for FILE in ../files/images/*
do 
    f_echo_magenta "[${SCRIPT_NAME}] Loading docker image: ${FILE}"
    docker load < $FILE
done
