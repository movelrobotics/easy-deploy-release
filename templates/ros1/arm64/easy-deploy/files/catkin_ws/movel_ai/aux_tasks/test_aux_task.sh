#!/bin/bash

function proc_start {
    rostopic pub /aux_task_status std_msgs/String "data: 'start'"

    while true
    do
        sleep 10
    done
}

function proc_exit {
    rostopic pub /aux_task_status std_msgs/String "data: 'stop'"
    exit 0
}

trap proc_exit TERM INT
proc_start
