#!/usr/bin/env bash
SCRIPT_NAME=$(basename ${BASH_SOURCE[0]})
source ../utils/bash_utils.sh

### main
SERVICE_FILE=movel-autostart.service

# create .service file
f_echo_magenta "[${SCRIPT_NAME}] Creating .service file: ${SERVICE_FILE}"
cp $SERVICE_FILE.tmpl $SERVICE_FILE
# set path in .service file
sed -i -e "s/{{ USER }}/${USER}/g" $SERVICE_FILE

# register .service file
f_echo_magenta "[${SCRIPT_NAME}] Registering service ..."
sudo cp $SERVICE_FILE /etc/systemd/system/$SERVICE_FILE
sudo chmod 644 /etc/systemd/system/$SERVICE_FILE
sudo systemctl enable $SERVICE_FILE

# start 
f_echo_magenta "[${SCRIPT_NAME}] Starting service ..."
sudo systemctl start $SERVICE_FILE