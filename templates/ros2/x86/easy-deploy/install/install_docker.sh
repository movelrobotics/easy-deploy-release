#!/usr/bin/env bash
SCRIPT_NAME=$(basename ${BASH_SOURCE[0]})
source ../utils/bash_utils.sh

# Setup architecture
if [[ "${ARCH}" == "x86" ]]; then
   arch="amd64"
elif [[ "${ARCH}" == "arm64" ]]; then
   arch="arm64"
else
   echo "Invalid arch ${ARCH}"
   exit 1
fi

# Install utilities
sudo apt update && sudo apt install -y curl ca-certificates gnupg

# Add Docker's official GPG key:

sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update

# Docker install
if CMD=$(docker --version); then 
    f_echo_magenta "[${SCRIPT_NAME}] Docker already installed: ${CMD}"
else
    f_echo_magenta "[${SCRIPT_NAME}] Installing Docker ..."
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    if [ $? -ne 0 ]; then 
        f_echo_red "[${SCRIPT_NAME}] Installing Docker failed!"
        f_echo_red "[${SCRIPT_NAME}] ABORT INSTALLATION!"
        exit 1
    fi
fi

# Docker Compose check (new method)
if CMD=$(docker compose version); then 
    f_echo_magenta "[${SCRIPT_NAME}] Docker Compose already installed: ${CMD}"
else
    f_echo_magenta "[${SCRIPT_NAME}] Installing Docker Compose ..."
    sudo apt install -y docker-compose-plugin
    if [ $? -ne 0 ]; then 
        f_echo_red "[${SCRIPT_NAME}] Installing Docker Compose failed!"
        f_echo_red "[${SCRIPT_NAME}] ABORT INSTALLATION!"
        exit 1
    fi
fi

# Add user to docker group
sudo usermod -aG docker $USER


f_echo_green "[${SCRIPT_NAME}] Docker installation completed!"


