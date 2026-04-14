if [ -f "/opt/ros/${ROS_DISTRO}/setup.bash" ]; then
  source "/opt/ros/${ROS_DISTRO}/setup.bash"
fi

export ROS_AUTOMATIC_DISCOVERY_RANGE="${ROS_AUTOMATIC_DISCOVERY_RANGE:-LOCALHOST}"
export TURTLEBOT3_MODEL="${TURTLEBOT3_MODEL:-waffle}"
export ROS_DOMAIN_ID="${ROS_DOMAIN_ID:-30}"
export ROBOT_IP="${ROBOT_IP:-192.168.0.10}"

if [ -f "$HOME/ros2_ws/install/local_setup.bash" ]; then
  source "$HOME/ros2_ws/install/local_setup.bash"
fi

alias zenoh='zenoh-bridge-ros2dds -e tcp/$ROBOT_IP:7447'
alias colcon_clear='rm -rf build install log'
