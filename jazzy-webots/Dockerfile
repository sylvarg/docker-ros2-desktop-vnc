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
# Select how Webots is provided to the ROS container:
# - bundled: install the native Linux Webots package inside the image
# - external: install only the ROS/Webots bridge and connect to a host Webots
#   instance through the upstream shared-folder/TCP workflow
ARG WEBOTS_BACKEND=bundled
# When enabled, patch WebotsLauncher so worlds launched through
# webots_ros2_driver get a default wbproj layout when they don't ship one.
ARG ENABLE_WEBOTS_LAUNCHER_DEFAULT_WBPROJ_PATCH=true

LABEL maintainer="Sylvain ARGENTIERI<sylvain.argentieri@sorbonne-universite.fr>"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV DEBIAN_FRONTEND=noninteractive
ENV ROS_DISTRO=jazzy
ENV TZ=Europe/Paris
ENV USER=turtle
ENV ROS_DESKTOP_VNC_DIR=/etc/ros-desktop-vnc

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

# Install ROS 2 Jazzy and the ROS/Webots bridge package.
# `ros-${ROS_DISTRO}-webots-ros2` is useful in both modes:
# - bundled: it launches the Linux Webots installed in the image
# - external: it prepares worlds/controllers and connects them to a host Webots
#   instance through the upstream remote workflow documented for macOS/Windows
RUN curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key \
    -o /usr/share/keyrings/ros-archive-keyring.gpg && \
    curl -sSL https://download.eclipse.org/zenoh/debian-repo/zenoh-public-key \
    | gpg --dearmor --yes -o /usr/share/keyrings/zenoh-public-key.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu $(lsb_release -cs) main" \
    > /etc/apt/sources.list.d/ros2.list && \
    echo "deb [signed-by=/usr/share/keyrings/zenoh-public-key.gpg] https://download.eclipse.org/zenoh/debian-repo/ /" \
    > /etc/apt/sources.list.d/eclipse-zenoh.list && \
    apt-get update -q && \
    apt-get install -y \
    ros-${ROS_DISTRO}-${INSTALL_PACKAGE} \
    ros-${ROS_DISTRO}-webots-ros2 \
    python3-argcomplete \
    python3-colcon-common-extensions \
    python3-rosdep \
    zenoh-bridge-ros2dds \
    python3-vcstool && \
    rosdep init && \
    rosdep update && \
    rm -rf /var/lib/apt/lists/*

# Install native Linux Webots only for the bundled backend on amd64.
# On arm64 we intentionally skip it because Cyberbotics does not ship a Linux
# arm64 package. The external backend is the intended path there, especially on
# Apple Silicon where native macOS Webots avoids slow amd64 emulation.
RUN if [[ "${WEBOTS_BACKEND}" == "bundled" && "$TARGETARCH" == "amd64" ]]; then \
    wget -q https://cyberbotics.com/Cyberbotics.asc \
    -O /etc/apt/keyrings/Cyberbotics.asc && \
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/Cyberbotics.asc] https://cyberbotics.com/debian binary-amd64/" \
    > /etc/apt/sources.list.d/Cyberbotics.list && \
    apt-get update -q && \
    apt-get install -y webots && \
    rm -rf /var/lib/apt/lists/*; \
    elif [[ "${WEBOTS_BACKEND}" == "bundled" ]]; then \
    echo "Skipping bundled Linux Webots install on unsupported architecture: $TARGETARCH"; \
    else \
    echo "Using external Webots backend; skipping native Linux Webots install"; \
    fi

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
COPY --chmod=644 ./config/bashrc.ros2_desktop_vnc.sh ${ROS_DESKTOP_VNC_DIR}/bashrc.sh
# Default colcon configuration copied into user workspaces.
COPY --chmod=644 ./config/colcon-defaults.yaml ${ROS_DESKTOP_VNC_DIR}/colcon-defaults.yaml
# Runtime templates copied by the entrypoint into the user home and Supervisor.
COPY --chmod=755 ./config/xstartup.sh ${ROS_DESKTOP_VNC_DIR}/xstartup.sh
COPY --chmod=755 ./config/vnc_run.sh ${ROS_DESKTOP_VNC_DIR}/vnc_run.sh
COPY --chmod=644 ./config/webots-default.conf ${ROS_DESKTOP_VNC_DIR}/webots-default.conf
COPY --chmod=644 ./config/webots-empty.wbproj ${ROS_DESKTOP_VNC_DIR}/webots-empty.wbproj
COPY --chmod=644 ./config/supervisord.conf.template ${ROS_DESKTOP_VNC_DIR}/supervisord.conf.template
# Versioned unified diff for the upstream ROS 2 Webots launcher. Keeping the
# patch as a diff makes the override reviewable against the original file.
COPY --chmod=644 ./patches/webots_launcher.patch ${ROS_DESKTOP_VNC_DIR}/webots_launcher.patch
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
    chmod 755 ${ROS_DESKTOP_VNC_DIR} /usr/local/share/ros-desktop-vnc /usr/local/share/ros-desktop-vnc/background /usr/local/share/ros-desktop-vnc/desktop

# Override the default Webots project layout only when the Linux simulator is
# bundled in the image. The external backend uses the same wbproj template via
# the patched ROS launcher below, so host-launched simulations still benefit
# from the simplified default layout.
RUN if [[ "${WEBOTS_BACKEND}" == "bundled" && "$TARGETARCH" == "amd64" && -d /usr/local/webots/resources/projects/worlds ]]; then \
    cp ${ROS_DESKTOP_VNC_DIR}/webots-empty.wbproj /usr/local/webots/resources/projects/worlds/.empty.wbproj; \
    fi

# Patch the ROS 2 Webots launcher in both backends. The launcher belongs to the
# ROS package, not to the simulator install itself, so this remains useful when
# Webots runs on the host: the world copy staged by `webots_ros2_driver` still
# gets the repo-provided default wbproj layout before being handed off to Webots.
RUN if [[ "${ENABLE_WEBOTS_LAUNCHER_DEFAULT_WBPROJ_PATCH}" == "true" && -f /opt/ros/jazzy/lib/python3.12/site-packages/webots_ros2_driver/webots_launcher.py ]]; then \
    cp /opt/ros/jazzy/lib/python3.12/site-packages/webots_ros2_driver/webots_launcher.py /opt/ros/jazzy/lib/python3.12/site-packages/webots_ros2_driver/webots_launcher.py.orig && \
    cd /opt/ros/jazzy/lib/python3.12/site-packages/webots_ros2_driver && \
    patch -p1 < ${ROS_DESKTOP_VNC_DIR}/webots_launcher.patch; \
    fi

# Seed root and future user homes with ROS workspace defaults and desktop shortcuts.
RUN install -d /etc/skel/.colcon /etc/skel/Desktop /etc/skel/ros2_ws/src \
    /root/.colcon /root/Desktop /root/ros2_ws/src && \
    cp ${ROS_DESKTOP_VNC_DIR}/colcon-defaults.yaml /etc/skel/.colcon/defaults.yaml && \
    cp ${ROS_DESKTOP_VNC_DIR}/colcon-defaults.yaml /root/.colcon/defaults.yaml && \
    cp /usr/local/share/ros-desktop-vnc/desktop/*.desktop /etc/skel/Desktop/ && \
    cp /usr/local/share/ros-desktop-vnc/desktop/*.desktop /root/Desktop/ && \
    printf '\nif [ -f %s/bashrc.sh ]; then\n  source %s/bashrc.sh\nfi\n' "${ROS_DESKTOP_VNC_DIR}" "${ROS_DESKTOP_VNC_DIR}" >> /etc/skel/.bashrc && \
    printf '\nif [ -f %s/bashrc.sh ]; then\n  source %s/bashrc.sh\nfi\n' "${ROS_DESKTOP_VNC_DIR}" "${ROS_DESKTOP_VNC_DIR}" >> /root/.bashrc

COPY --chmod=755 ./entrypoint.sh /entrypoint.sh
RUN dos2unix /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
