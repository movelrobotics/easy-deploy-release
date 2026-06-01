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

echo "Please ensure that you are not running this with sudo privileges!"

echo "Press any key to continue..."
read -s -n 1

cd $SCRIPT_DIR/install

# machine architecture check
f_echo_red "[${SCRIPT_NAME}] Checking machine architecture ..."
bash check_arch.sh || exit 1
f_echo_green "[${SCRIPT_NAME}] Checking machine architecture done"

# docker
f_echo_red "[${SCRIPT_NAME}] Installing docker and docker-compose ..."
bash install_docker.sh || exit 1
f_echo_green "[${SCRIPT_NAME}] Installing docker and docker-compose done"

# end (print this before re-login)
f_echo_cyan "[${SCRIPT_NAME}] ===== END ====="

# re-login to apply changes to user group
f_echo_green "[${SCRIPT_NAME}] Re-login shell ..."
cd $SCRIPT_DIR   # come back to top dir before re-login
sudo su $USER   # re-login