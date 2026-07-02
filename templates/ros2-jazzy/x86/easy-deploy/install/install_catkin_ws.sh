#!/usr/bin/env bash
SCRIPT_NAME=$(basename ${BASH_SOURCE[0]})
source ../utils/bash_utils.sh

# utils
function f_make_dir_if_not_exists {
    SUB_DIR=$1
    if [ ! -d "${SUB_DIR}" ]; then   # not exists
        f_echo_magenta "[${SCRIPT_NAME}] Creating sub-dir ${SUB_DIR}"
        mkdir -p $SUB_DIR
    else # do not overwrite
        f_echo_magenta "[${SCRIPT_NAME}] ${SUB_DIR} folder already exists"
    fi
}
function f_copy_folder_if_not_exists {
    SRC_DIR=$1
    SUB_DIR=$2
    if [ ! -d "${SUB_DIR}" ]; then   # not exists
        f_echo_magenta "[${SCRIPT_NAME}] Creating sub-dir ${SUB_DIR}. Copying files from ${SRC_DIR}"
        cp -r $SRC_DIR $SUB_DIR
    else   # do not overwrite config
        f_echo_magenta "[${SCRIPT_NAME}] ${SUB_DIR} folder already exists. Skip copying files"
    fi
}
function f_copy_file_if_not_exists {
    SRC=$1
    FILE=$2
    if [ ! -f "${FILE}" ]; then   # not exists
        f_echo_magenta "[${SCRIPT_NAME}] Creating file ${FILE} from source ${SRC}"
        cp $SRC $FILE
    else   # do not overwrite config
        f_echo_magenta "[${SCRIPT_NAME}] File already exists ${FILE}. Skip copying file"
    fi
}

# create catkin_ws
CATKIN_DIR="/home/${USER}/catkin_ws"
f_echo_magenta "[${SCRIPT_NAME}] Preparing ${CATKIN_DIR} ..."

if [ ! -d "${CATKIN_DIR}" ]; then   # no existing catkin_ws
    # copy whole catkin_ws to home
    f_echo_magenta "[${SCRIPT_NAME}] Creating catkin_ws in ${CATKIN_DIR}"
    cp -r ../files/catkin_ws /home/$USER
    mkdir -p \
        ${CATKIN_DIR}/src \
        ${CATKIN_DIR}/movel_ai/maps/nav \
        ${CATKIN_DIR}/movel_ai/paths \
        ${CATKIN_DIR}/movel_ai/aux_tasks \
        ${CATKIN_DIR}/movel_ai/maps/transit_points

else   # catkin_ws exists
    # create sub dirs one by one if not exists
    f_echo_magenta "[${SCRIPT_NAME}] catkin_ws already exists in ${CATKIN_DIR}"
    
    # maps/nav
    SUB_DIR="${CATKIN_DIR}/movel_ai/maps/nav"
    f_make_dir_if_not_exists $SUB_DIR 
    
    # paths
    SUB_DIR="${CATKIN_DIR}/movel_ai/paths"
    f_make_dir_if_not_exists $SUB_DIR 

    # aux_tasks
    SUB_DIR="${CATKIN_DIR}/movel_ai/aux_tasks"
    f_make_dir_if_not_exists $SUB_DIR 
    
    # config
    SRC_DIR="../files/catkin_ws/movel_ai/config"
    SUB_DIR="${CATKIN_DIR}/movel_ai/config"
    f_copy_folder_if_not_exists $SRC_DIR $SUB_DIR
    
    # graph_files
    SUB_DIR="${CATKIN_DIR}/movel_ai/maps/graph_files"
    f_make_dir_if_not_exists $SUB_DIR
    
    # transit_points
    SUB_DIR="${CATKIN_DIR}/movel_ai/maps/transit_points"
    f_make_dir_if_not_exists $SUB_DIR 
    
    # docker-compose.yaml
    SRC="../files/catkin_ws/movel_ai/docker-compose.yaml"
    FILE="${CATKIN_DIR}/movel_ai/docker-compose.yaml"
    f_copy_file_if_not_exists $SRC $FILE

    # rabbitmq.conf
    SRC="../files/catkin_ws/movel_ai/rabbitmq.conf"
    FILE="${CATKIN_DIR}/movel_ai/rabbitmq.conf"
    f_copy_file_if_not_exists $SRC $FILE
    
    # autostart.sh
    SRC="../files/catkin_ws/movel_ai/autostart.sh"
    FILE="${CATKIN_DIR}/movel_ai/autostart.sh"
    f_copy_file_if_not_exists $SRC $FILE
    
    # license
    SRC_DIR="../files/catkin_ws/movel_ai/license"
    SUB_DIR="${CATKIN_DIR}/movel_ai/license"
    f_copy_folder_if_not_exists $SRC_DIR $SUB_DIR
    
    # license
    SRC_DIR="../files/catkin_ws/movel_ai/graph_files"
    SUB_DIR="${CATKIN_DIR}/movel_ai/maps/graph_files"
    f_copy_folder_if_not_exists $SRC_DIR $SUB_DIR
fi

# set permissions
f_echo_magenta "[${SCRIPT_NAME}] Setting catkin_ws permissions ..."
sudo chmod 2777 \
    $CATKIN_DIR/movel_ai/config \
    $CATKIN_DIR/movel_ai/maps \
    $CATKIN_DIR/movel_ai/maps/nav \
    $CATKIN_DIR/movel_ai/paths \
    $CATKIN_DIR/movel_ai/aux_tasks \
    $CATKIN_DIR/movel_ai/maps/graph_files \
    $CATKIN_DIR/movel_ai/maps/transit_points
