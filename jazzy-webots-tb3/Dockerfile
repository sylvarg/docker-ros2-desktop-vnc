# syntax=docker/dockerfile:1.7

# build.sh / build.ps1 build this parent from the current jazzy-webots sources,
# with native Webots omitted. No published parent image is required.
ARG BASE_IMAGE=ros2-desktop-vnc:jazzy-webots-tb3-base
FROM ${BASE_IMAGE}

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
USER root

# This variant always uses native host Webots. Only the host-side shared path
# needs overriding on Windows or when using a different exchange directory.
ENV WEBOTS_BACKEND=external \
    WEBOTS_SHARED_FOLDER=/tmp/ros2-desktop-vnc-webots-shared:/home/turtle/webots_shared \
    TURTLEBOT3_WS=/opt/turtlebot3_ws

# URDF controls and vision compatibility for the labs. The parent installs pip
# NumPy through websockify; NumPy 2 shadows Ubuntu's NumPy 1.x and prevents its
# OpenCV/cv_bridge extensions from loading. Apply the compatibility constraint
# before building the robot packages, without changing the shared Jazzy base.
RUN apt-get update -q && \
    apt-get install -y --no-install-recommends ros-${ROS_DISTRO}-joint-state-publisher-gui && \
    python3 -m pip install --no-cache-dir --break-system-packages 'numpy<2' && \
    rm -rf /var/lib/apt/lists/*

# Follow ROBOTIS' Jazzy PC setup using the three source repositories. colcon,
# rosdep and the usual ROS desktop dependencies already come from the parent.
# Resolve build dependencies only: the upstream repository also ships optional
# Cartographer/Nav2 launch packages whose runtime stacks are intentionally absent.
# Keep this layer before the wallpaper and SSH customization so those changes do
# not force a rebuild of the robot packages.
RUN install -d "${TURTLEBOT3_WS}/src" && \
    git clone --depth 1 --branch jazzy https://github.com/ROBOTIS-GIT/DynamixelSDK.git "${TURTLEBOT3_WS}/src/DynamixelSDK" && \
    git clone --depth 1 --branch jazzy https://github.com/ROBOTIS-GIT/turtlebot3_msgs.git "${TURTLEBOT3_WS}/src/turtlebot3_msgs" && \
    git clone --depth 1 --branch jazzy https://github.com/ROBOTIS-GIT/turtlebot3.git "${TURTLEBOT3_WS}/src/turtlebot3" && \
    source "/opt/ros/${ROS_DISTRO}/setup.bash" && \
    apt-get update -q && \
    rosdep update --rosdistro "${ROS_DISTRO}" && \
    rosdep install --from-paths "${TURTLEBOT3_WS}/src" --ignore-src --rosdistro "${ROS_DISTRO}" \
        --dependency-types=build --dependency-types=buildtool \
        --dependency-types=build_export --dependency-types=buildtool_export -y && \
    if [[ -f /root/.colcon/defaults.yaml ]]; then \
        mv /root/.colcon/defaults.yaml /tmp/tb3-colcon-defaults.yaml; \
    fi && \
    cd "${TURTLEBOT3_WS}" && \
    colcon build --merge-install --cmake-args -DBUILD_TESTING=OFF && \
    if [[ -f /tmp/tb3-colcon-defaults.yaml ]]; then \
        mv /tmp/tb3-colcon-defaults.yaml /root/.colcon/defaults.yaml; \
    fi && \
    rm -rf "${TURTLEBOT3_WS}/build" "${TURTLEBOT3_WS}/log" /var/lib/apt/lists/* && \
    chmod -R a+rX "${TURTLEBOT3_WS}"

# Load the prebuilt robot packages before the user's development workspace.
COPY --chmod=644 ./config/20-turtlebot3.sh ${ROS_DESKTOP_VNC_DIR}/bashrc.d/20-turtlebot3.sh

# Dedicated wallpaper for the labs, initially copied from rosconfr without its ROS overlay.
COPY --chmod=644 ./background/ /usr/local/share/ros-desktop-vnc/background/
COPY --chmod=644 ./config/90_ros2-desktop-vnc.gschema.override /usr/share/glib-2.0/schemas/90_ros2-desktop-vnc.gschema.override
RUN glib-compile-schemas /usr/share/glib-2.0/schemas

# Preserve native browser paste (Cmd+V / Ctrl+V) and refresh clipboard sync when
# returning to an already focused VNC canvas. No browser-wide permissions needed
# for the native paste event.
COPY --chmod=644 ./patches/novnc-clipboard.patch ${ROS_DESKTOP_VNC_DIR}/novnc-clipboard.patch
RUN patch --batch --forward -p1 -d /usr/lib/novnc < ${ROS_DESKTOP_VNC_DIR}/novnc-clipboard.patch

# Keep the robot address directly editable in each user's .bashrc. Append it
# after the shared initialization so editing it and running `sb` takes effect
# even when the shell already exports the previous address.
RUN sed -i 's/ROBOT_IP/TB3_IP/g' "${ROS_DESKTOP_VNC_DIR}/bashrc.sh" && \
    for bashrc_path in /etc/skel/.bashrc /root/.bashrc; do \
        printf '\n# Adresse IP du TurtleBot3 pour la commande zenoh.\n# Modifier cette ligne puis recharger avec : sb\nexport TB3_IP=192.168.0.248\n' >> "$bashrc_path"; \
    done

# The inherited entrypoint seeds ~/.ssh without overwriting existing files and
# enforces ownership and permissions. The optional key becomes part of the image.
# BuildKit secrets do not invalidate the cache: pass the public fingerprint when
# adding or replacing a key so this layer cannot reuse a different SSH seed.
ARG TB3_SSH_KEY_FINGERPRINT=none
RUN --mount=type=secret,id=tb3_ssh_key,required=false \
    : "${TB3_SSH_KEY_FINGERPRINT}" && \
    if [[ -f /run/secrets/tb3_ssh_key ]]; then \
        install -d -m 700 /etc/skel/.ssh && \
        install -m 600 /run/secrets/tb3_ssh_key /etc/skel/.ssh/id_rsa_tb3 && \
        ssh-keygen -y -f /run/secrets/tb3_ssh_key > /etc/skel/.ssh/id_rsa_tb3.pub && \
        chmod 644 /etc/skel/.ssh/id_rsa_tb3.pub && \
        printf '%s\n' \
            'Host *' \
            '    IdentityFile ~/.ssh/id_rsa_tb3' \
            > /etc/skel/.ssh/config && \
        chmod 600 /etc/skel/.ssh/config; \
    fi

# Desktop startup, ROS shell defaults, Webots patches and SSH initialization
# are inherited unchanged from the parent image.
