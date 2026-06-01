#!/usr/bin/env bash
SCRIPT_NAME=$(basename ${BASH_SOURCE[0]})
source ../utils/bash_utils.sh

# Check Docker
if CMD=$(docker --version); then 
    f_echo_magenta "[${SCRIPT_NAME}] Docker check: ${CMD}"
else
    f_echo_red "[${SCRIPT_NAME}] Docker check failed. Docker is not installed."
    exit 1
fi

# Check Docker Compose (use new command)
if CMD=$(docker compose version); then 
    f_echo_magenta "[${SCRIPT_NAME}] Docker Compose check: ${CMD}"
else
    f_echo_red "[${SCRIPT_NAME}] Docker Compose check failed. Ensure Docker is installed correctly."
    exit 1
fi

# Check Docker Permissions
if docker image ls &>/dev/null; then 
    f_echo_magenta "[${SCRIPT_NAME}] Docker permission check: passed"
else
    f_echo_red "[${SCRIPT_NAME}] Docker permission check failed!"
    f_echo_yellow "Try logging out and back in, or run: newgrp docker"
    exit 1
fi

