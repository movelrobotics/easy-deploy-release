#!/usr/bin/env bash
SCRIPT_NAME=$(basename ${BASH_SOURCE[0]})
source ../utils/bash_utils.sh

# setup
if [[ "${ARCH}" == "x86" ]]; then
   arch="amd64"
elif [[ "${ARCH}" == "arm64" ]]; then
   arch="arm64"
else
   echo "Invalid arch ${ARCH}"
   exit 1
fi
# install utilities
sudo apt update && sudo apt install -y curl 
# docker apt registry
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=${arch}] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"
sudo apt update

# docker install
if CMD=$(docker --version) ; then 
    f_echo_magenta "[${SCRIPT_NAME}] docker already installed: ${CMD}"
else
    f_echo_magenta "[${SCRIPT_NAME}] Installing docker ..."
    sudo apt install -y docker-ce
    if [ $? -ne 0 ]; then 
        f_echo_red "[${SCRIPT_NAME}] Installing docker failed!"
        f_echo_red "[${SCRIPT_NAME}] ABORT INSTALLATION!"
        exit 1
    fi
fi

# docker-compose install
if CMD=$(docker-compose --version) ; then 
    f_echo_magenta "[${SCRIPT_NAME}] docker-compose already installed: ${CMD}"
else
    f_echo_magenta "[${SCRIPT_NAME}] Installing docker-compose ..."
    sudo apt install -y docker-compose
    if [ $? -ne 0 ]; then 
        f_echo_red "[${SCRIPT_NAME}] Installing docker-compose failed!"
        f_echo_red "[${SCRIPT_NAME}] ABORT INSTALLATION!"
        exit 1
    fi
fi

# add user to docker group
sudo usermod -aG docker $USER