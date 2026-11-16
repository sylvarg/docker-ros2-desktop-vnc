# The base shell initialization has already sourced ROS Jazzy. Use local_setup
# to add the robot packages before ~/ros2_ws, which remains the final overlay.
if [ -f "${TURTLEBOT3_WS}/install/local_setup.bash" ]; then
  source "${TURTLEBOT3_WS}/install/local_setup.bash"
fi
