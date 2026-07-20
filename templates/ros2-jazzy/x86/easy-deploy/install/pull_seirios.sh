#!/usr/bin/env bash
SCRIPT_NAME=$(basename ${BASH_SOURCE[0]})
source ../utils/bash_utils.sh

# pulling docker images

cd /home/${USER}/catkin_ws/movel_ai
docker compose pull
