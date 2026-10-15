#!/usr/bin/env bash

#===========================
# Movel autostart service
#===========================
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# NOTE: 
# >> This script will only run once on startup 
# >> All services added here must run in the background!
# >> Eg. add robot motor and sensor drivers launchers here
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

#*********************************************************
SCRIPT_DIR=$(cd $(dirname ${BASH_SOURCE[0]}) && pwd)

### Add services here

# seirios docker
cd $SCRIPT_DIR && docker compose up -d

#*********************************************************
