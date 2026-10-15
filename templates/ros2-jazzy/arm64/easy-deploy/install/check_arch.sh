#!/usr/bin/env bash
SCRIPT_NAME=$(basename ${BASH_SOURCE[0]})
source ../utils/bash_utils.sh

# machine architecture check
ARCH_EASY_DEPLOY=$(cat ../ARCH.txt)
ARCH_MACHINE=$(uname -m)
if [[ "${ARCH_EASY_DEPLOY}" == "x86" ]]; then
    if [[ "${ARCH_MACHINE}" != "x86_64" ]]; then
        f_echo_red "[${SCRIPT_NAME}] Architecture does not match!"
        f_echo_red "[${SCRIPT_NAME}] ABORT INSTALLATION!"
        exit 1
    fi
elif [[ "${ARCH_EASY_DEPLOY}" == "arm64" ]]; then
    if [[ "${ARCH_MACHINE}" != "aarch64" ]]; then
        f_echo_red "[${SCRIPT_NAME}] Architecture does not match!"
        f_echo_red "[${SCRIPT_NAME}] ABORT INSTALLATION!"
        exit 1
    fi
fi