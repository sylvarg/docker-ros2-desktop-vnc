# syntax=docker/dockerfile:1.7

ARG BASE_IMAGE=ros2-desktop-vnc:jazzy-webots-tb3
FROM ${BASE_IMAGE}

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
USER root

ENV NED2_WS=/opt/ned2_ws

# Niryo provides the ROS 2 bridge, robot description and MoveIt 2 configuration.
# Build these once in the image; lab code and Webots worlds live in ~/ros2_ws.
ARG NED2_DRIVER_REF=27d8345d8858769975956186947c1194d0b084b2
RUN apt-get update -q && \
    apt-get install -y --no-install-recommends \
        ros-${ROS_DISTRO}-moveit ros-${ROS_DISTRO}-moveit-py \
        ros-${ROS_DISTRO}-joint-trajectory-controller && \
    install -d "${NED2_WS}/src/ned-ros2-driver" && \
    git -C "${NED2_WS}/src/ned-ros2-driver" init -q && \
    git -C "${NED2_WS}/src/ned-ros2-driver" fetch --depth 1 \
        https://github.com/NiryoRobotics/ned-ros2-driver.git "${NED2_DRIVER_REF}" && \
    git -C "${NED2_WS}/src/ned-ros2-driver" checkout -q --detach FETCH_HEAD && \
    python3 -m pip install --no-cache-dir --break-system-packages \
        -r "${NED2_WS}/src/ned-ros2-driver/requirements.txt" && \
    source "/opt/ros/${ROS_DISTRO}/setup.bash" && \
    cd "${NED2_WS}" && \
    COLCON_DEFAULTS_FILE=/dev/null colcon build --merge-install \
        --packages-up-to niryo_ned_ros2_driver niryo_ned2_moveit_config \
        --cmake-args -DBUILD_TESTING=OFF && \
    rm -rf build log src/ned-ros2-driver/.git /var/lib/apt/lists/* && \
    chmod -R a+rX "${NED2_WS}"

COPY --chmod=644 ./config/30-ned2.sh ${ROS_DESKTOP_VNC_DIR}/bashrc.d/30-ned2.sh

COPY --chmod=644 ./config/tb3_zenoh.json5 ${ROS_DESKTOP_VNC_DIR}/tb3_zenoh.json5

# Accept older TB3 parent tags and let the Ned2 shell overlay define zenoh.
RUN sed -i -e 's/ROBOT_IP/TB3_IP/g' -e '/^alias zenoh=/d' \
        "${ROS_DESKTOP_VNC_DIR}/bashrc.sh" /etc/skel/.bashrc /root/.bashrc
