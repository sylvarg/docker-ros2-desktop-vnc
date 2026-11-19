if [ -f "${NED2_WS}/install/local_setup.bash" ]; then
  source "${NED2_WS}/install/local_setup.bash"
fi

alias zenoh='zenoh-bridge-ros2dds -c "${ROS_DESKTOP_VNC_DIR}/tb3_zenoh.json5" -e "tcp/${TB3_IP}:7447"'
