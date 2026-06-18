if [ -f "/opt/ros/${ROS_DISTRO}/setup.bash" ]; then
  source "/opt/ros/${ROS_DISTRO}/setup.bash"
fi

export ROS_AUTOMATIC_DISCOVERY_RANGE="${ROS_AUTOMATIC_DISCOVERY_RANGE:-LOCALHOST}"
export TURTLEBOT3_MODEL="${TURTLEBOT3_MODEL:-burger}"
export ROS_DOMAIN_ID="${ROS_DOMAIN_ID:-30}"
export ROBOT_IP="${ROBOT_IP:-192.168.0.10}"

if [ -d "/usr/local/webots" ]; then
  export WEBOTS_HOME="${WEBOTS_HOME:-/usr/local/webots}"
  export ROS2_WEBOTS_HOME="${ROS2_WEBOTS_HOME:-/usr/local/webots}"
fi

# Source image-provided shell overlays before the user workspace so a mounted
# development workspace can still override them when needed.
for ros_desktop_vnc_bashrc in "${ROS_DESKTOP_VNC_DIR}/bashrc.d/"*.sh; do
  if [ -f "$ros_desktop_vnc_bashrc" ]; then
    source "$ros_desktop_vnc_bashrc"
  fi
done

if [ -f "$HOME/ros2_ws/install/local_setup.bash" ]; then
  source "$HOME/ros2_ws/install/local_setup.bash"
fi

alias zenoh='zenoh-bridge-ros2dds -e tcp/$ROBOT_IP:7447'
alias colcon_clear='rm -rf build install log'
alias sb='source ~/.bashrc'
alias eb='nano ~/.bashrc'
