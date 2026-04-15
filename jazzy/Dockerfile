# Copyright 2020-2024 Tiryoh<tiryoh@gmail.com>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# This Dockerfile is adapted from https://github.com/Tiryoh/docker-ros2-desktop-vnc/tree/master
# which is released under the Apache-2.0 license.

FROM ubuntu:noble-20260324

# Automatic platform ARGs in the global scope
# https://docs.docker.com/reference/dockerfile/#automatic-platform-args-in-the-global-scope
ARG TARGETPLATFORM
ARG TARGETARCH

# The QEMU_CPU option is used to speed up arm64 image builds,
# amd64 is unaffected as it does not use QEMU.
# This environment variable is only declared at build time.
ARG QEMU_CPU
ARG INSTALL_PACKAGE=desktop

LABEL maintainer="Sylvain ARGENTIERI<sylvain.argentieri@sorbonne-universite.fr>"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV DEBIAN_FRONTEND=noninteractive
ENV ROS_DISTRO=jazzy
ENV TZ=Europe/Paris
ENV USER=turtle

# Base system and desktop environment
RUN apt-get update -q && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
    ubuntu-mate-core \
    bash-completion \
    build-essential \
    ca-certificates \
    curl \
    dos2unix \
    git \
    gnupg2 \
    gosu \
    iputils-ping \
    locales \
    lsb-release \
    nano \
    nextcloud-desktop \
    python3-full \
    python3-pip \
    sudo \
    supervisor \
    terminator \
    tigervnc-common \
    tigervnc-standalone-server \
    tigervnc-tools \
    tini \
    tzdata \
    vim \
    wget && \
    locale-gen en_US.UTF-8 && \
    rm -rf /var/lib/apt/lists/*

ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# noVNC and Websockify
RUN git clone --depth 1 --branch add_clipboard_support https://github.com/AtsushiSaito/noVNC.git /usr/lib/novnc && \
    python3 -m pip install --no-cache-dir --break-system-packages git+https://github.com/novnc/websockify.git@v0.10.0 && \
    ln -s /usr/lib/novnc/vnc.html /usr/lib/novnc/index.html && \
    sed -i "s/UI.initSetting('resize', 'off');/UI.initSetting('resize', 'remote');/g" /usr/lib/novnc/app/ui.js

# Disable auto update and crash report
RUN sed -i 's/Prompt=.*/Prompt=never/' /etc/update-manager/release-upgrades && \
    if [ -f /etc/default/apport ]; then sed -i 's/enabled=1/enabled=0/g' /etc/default/apport; fi

# Install Firefox
RUN install -d -m 0755 /etc/apt/keyrings && \
    wget -q https://packages.mozilla.org/apt/repo-signing-key.gpg -O /etc/apt/keyrings/packages.mozilla.org.asc && \
    echo "deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main" \
    > /etc/apt/sources.list.d/mozilla-apt.list && \
    printf 'Package: *\nPin: origin packages.mozilla.org\nPin-Priority: 900\n' \
    > /etc/apt/preferences.d/mozilla-apt && \
    apt-get update -q && \
    apt-get install -y firefox && \
    rm -rf /var/lib/apt/lists/*

# Install VSCodium
RUN wget -q https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/raw/master/pub.gpg \
    -O /usr/share/keyrings/vscodium-archive-keyring.asc && \
    echo "deb [signed-by=/usr/share/keyrings/vscodium-archive-keyring.asc] https://paulcarroty.gitlab.io/vscodium-deb-rpm-repo/debs vscodium main" \
    > /etc/apt/sources.list.d/vscodium.list && \
    apt-get update -q && \
    apt-get install -y codium && \
    rm -rf /var/lib/apt/lists/*

# Install ROS 2 Jazzy
RUN curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key \
    -o /usr/share/keyrings/ros-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu $(lsb_release -cs) main" \
    > /etc/apt/sources.list.d/ros2.list && \
    echo "deb [trusted=yes] https://download.eclipse.org/zenoh/debian-repo/ /" \
    > /etc/apt/sources.list.d/eclipse-zenoh.list && \
    apt-get update -q && \
    apt-get install -y \
    ros-${ROS_DISTRO}-${INSTALL_PACKAGE} \
    python3-argcomplete \
    python3-colcon-common-extensions \
    python3-rosdep \
    zenoh-bridge-ros2dds \
    python3-vcstool && \
    rosdep init && \
    rosdep update && \
    rm -rf /var/lib/apt/lists/*

# # Install Gazebo
# RUN curl -sSL https://packages.osrfoundation.org/gazebo.gpg \
#         -o /usr/share/keyrings/pkgs-osrf-archive-keyring.gpg && \
#     echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/pkgs-osrf-archive-keyring.gpg] http://packages.osrfoundation.org/gazebo/ubuntu-stable $(lsb_release -cs) main" \
#         > /etc/apt/sources.list.d/gazebo-stable.list && \
#     apt-get update -q && \
#     apt-get install -y \
#         gz-harmonic \
#         ros-${ROS_DISTRO}-ros-gz && \
#     rm -rf /var/lib/apt/lists/*

# Enable apt-get completion after running `apt-get update` in the container
RUN rm -f /etc/apt/apt.conf.d/docker-clean

 # Shell initialization shared by root and the runtime user.
 COPY --chmod=644 ./config/bashrc.ros2_desktop_vnc.sh /etc/ros-desktop-vnc/bashrc.sh
 # Default colcon configuration copied into user workspaces.
 COPY --chmod=644 ./config/colcon-defaults.yaml /etc/ros-desktop-vnc/colcon-defaults.yaml
 # GLib schema overrides for MATE panel and desktop defaults.
 COPY --chmod=644 ./config/90_ros2-desktop-vnc.gschema.override /usr/share/glib-2.0/schemas/90_ros2-desktop-vnc.gschema.override
 # Custom MATE panel layout with the launchers used by this image.
 COPY --chmod=644 ./config/ros2-desktop-vnc.layout /usr/share/mate-panel/layouts/ros2-desktop-vnc.layout
 # Wallpaper assets used as the default desktop background.
 COPY --chmod=644 ./background/ /usr/local/share/ros-desktop-vnc/background/
 # Desktop launcher entries exposed on the panel and desktop.
 COPY --chmod=755 ./desktop/ /usr/local/share/ros-desktop-vnc/desktop/

 # Compile the updated GLib schemas and fix permissions on shared asset directories.
 RUN glib-compile-schemas /usr/share/glib-2.0/schemas && \
    chmod 755 /etc/ros-desktop-vnc /usr/local/share/ros-desktop-vnc /usr/local/share/ros-desktop-vnc/background /usr/local/share/ros-desktop-vnc/desktop

 # Seed root and future user homes with ROS workspace defaults and desktop shortcuts.
 RUN install -d /etc/skel/.colcon /etc/skel/Desktop /etc/skel/ros2_ws/src \
    /root/.colcon /root/Desktop /root/ros2_ws/src && \
    cp /etc/ros-desktop-vnc/colcon-defaults.yaml /etc/skel/.colcon/defaults.yaml && \
    cp /etc/ros-desktop-vnc/colcon-defaults.yaml /root/.colcon/defaults.yaml && \
    cp /usr/local/share/ros-desktop-vnc/desktop/*.desktop /etc/skel/Desktop/ && \
    cp /usr/local/share/ros-desktop-vnc/desktop/*.desktop /root/Desktop/ && \
    printf '\nif [ -f /etc/ros-desktop-vnc/bashrc.sh ]; then\n  source /etc/ros-desktop-vnc/bashrc.sh\nfi\n' >> /etc/skel/.bashrc && \
    printf '\nif [ -f /etc/ros-desktop-vnc/bashrc.sh ]; then\n  source /etc/ros-desktop-vnc/bashrc.sh\nfi\n' >> /root/.bashrc

COPY --chmod=755 ./entrypoint.sh /entrypoint.sh
RUN dos2unix /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
