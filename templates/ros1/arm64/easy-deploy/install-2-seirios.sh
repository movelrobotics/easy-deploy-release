#!/usr/bin/env bash
SCRIPT_DIR=$(cd $(dirname ${BASH_SOURCE[0]}) && pwd)
SCRIPT_NAME=$(basename ${BASH_SOURCE[0]})
source $SCRIPT_DIR/utils/bash_utils.sh

### main
# arch
export ARCH=$(cat ARCH.txt)
f_echo_cyan "[${SCRIPT_NAME}] ARCH: ${ARCH}"

# start
f_echo_cyan "[${SCRIPT_NAME}] ===== START ====="
f_echo_cyan "[${SCRIPT_NAME}] == LITE_VERSION =="

echo "Please ensure that you are not running this with sudo privileges!"

echo "Press any key to continue..."

read -s -n 1

cd $SCRIPT_DIR/install

# machine architecture check
f_echo_red "[${SCRIPT_NAME}] Checking machine architecture ..."
bash check_arch.sh || exit 1
f_echo_green "[${SCRIPT_NAME}] Checking machine architecture done"

# docker check
f_echo_red "[${SCRIPT_NAME}] Checking docker installation ..."
bash check_docker.sh || exit 1
f_echo_green "[${SCRIPT_NAME}] Checking docker installation done"

# seirios
#f_echo_red "[${SCRIPT_NAME}] Loading seirios images ..."
#bash install_seirios.sh
#f_echo_green "[${SCRIPT_NAME}] Loading seirios images done"

# license
f_echo_red "[${SCRIPT_NAME}] Installing license ..."
bash install_license.sh
f_echo_green "[${SCRIPT_NAME}] Installing license done"

# catkin_ws
# license is created and then copied into catkin_ws
f_echo_red "[${SCRIPT_NAME}] Preparing catkin_ws ..."
bash install_catkin_ws.sh
f_echo_green "[${SCRIPT_NAME}] Preparing catkin_ws done"

# # autostart service
# f_echo_red "[${SCRIPT_NAME}] Creating autostart service ..."
# bash install_autostart_service.sh
# f_echo_green "[${SCRIPT_NAME}] Creating autostart service done"

# pulling seirios images
f_echo_red "[${SCRIPT_NAME}] Pulling seirios images ..."
bash pull_seirios.sh
f_echo_green "[${SCRIPT_NAME}] Pulling seirios images done"

# end
f_echo_cyan "[${SCRIPT_NAME}] ===== END ====="

# restart
f_echo_cyan "[${SCRIPT_NAME}] Attention: Please restart your system to complete the installation :)"

