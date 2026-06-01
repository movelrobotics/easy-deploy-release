#!/bin/bash

# setup ros environment
source "/opt/ros/$ROS_DISTRO/setup.bash"
# source /home/movel/kdlidar_ros/install/setup.bash
exec "$@"
