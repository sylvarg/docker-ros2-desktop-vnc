# syntax=docker/dockerfile:1.7
#
# Syntax intentionally kept simple so the image can be built with standard
# `docker buildx build` commands, regardless of whether the parent image is the
# embedded or external Webots variant.

# Select the parent jazzy-webots image by backend, matching the public tags:
# - sylvarg/ros2-desktop-vnc:jazzy-webots-embedded
# - sylvarg/ros2-desktop-vnc:jazzy-webots-external
#
# This keeps the rosconfr image build UX close to jazzy-webots: choose the
# flavor at build time through WEBOTS_BACKEND instead of editing the Dockerfile.
ARG BASE_IMAGE_REPOSITORY=sylvarg/ros2-desktop-vnc
ARG WEBOTS_BACKEND=embedded
FROM ${BASE_IMAGE_REPOSITORY}:jazzy-webots-${WEBOTS_BACKEND}

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Repository and install location of the prebuilt ROS overlay.
ARG ROSCONFR_REPOSITORY=https://github.com/sylvarg/rosconfr.git
ARG ROSCONFR_REF=main
ENV ROSCONFR_WS=/opt/rosconfr

USER root

# Override the parent image desktop background with the rosconfr wallpaper.
COPY --chmod=644 ./background/ /usr/local/share/ros-desktop-vnc/background/
COPY --chmod=644 ./config/90_ros2-desktop-vnc.gschema.override /usr/share/glib-2.0/schemas/90_ros2-desktop-vnc.gschema.override
RUN glib-compile-schemas /usr/share/glib-2.0/schemas

# Optionally bake a robot SSH private key into the image without storing it in
# the repository or leaking it through a build argument. When the secret is
# provided, the jazzy-webots entrypoint will later copy it into the runtime user's
# home as ~/.ssh/id_rsa_car_rosconfr with the expected SSH permissions.
RUN --mount=type=secret,id=rosconfr_ssh_key,required=false \
    if [[ -f /run/secrets/rosconfr_ssh_key ]]; then \
    install -d -m 700 /etc/skel/.ssh && \
    cp /run/secrets/rosconfr_ssh_key /etc/skel/.ssh/id_rsa_car_rosconfr && \
    printf '%s\n' \
    'Match host="10.10.10.*"' \
    'IdentityFile ~/.ssh/id_rsa_car_rosconfr' \
    'StrictHostKeyChecking no' \
    > /etc/skel/.ssh/config && \
    chmod 600 /etc/skel/.ssh/config && \
    chmod 600 /etc/skel/.ssh/id_rsa_car_rosconfr; \
    fi

# Clone rosconfr into an isolated workspace under /opt, resolve its system
# dependencies from package.xml, then build a merged ROS overlay so it can be
# sourced with a single local_setup.bash.
#
# The parent jazzy-webots image enables `symlink-install` in /root/.colcon for
# interactive development workspaces. That is convenient for a mounted user
# workspace, but not for a prebuilt image overlay: the generated environment
# hooks would point back to `${ROSCONFR_WS}/build`, which we want to discard
# from the final image. We therefore hide the inherited colcon defaults for the
# duration of the image build so `/opt/rosconfr/install` becomes self-contained.
RUN install -d "${ROSCONFR_WS}/src" && \
    git clone --depth 1 --branch "${ROSCONFR_REF}" "${ROSCONFR_REPOSITORY}" "${ROSCONFR_WS}/src/rosconfr" && \
    if [[ -f /root/.colcon/defaults.yaml ]]; then \
    mv /root/.colcon/defaults.yaml /tmp/rosconfr-colcon-defaults.yaml; \
    fi && \
    source "/opt/ros/${ROS_DISTRO}/setup.bash" && \
    rosdep update && \
    rosdep install --from-paths "${ROSCONFR_WS}/src" --ignore-src --rosdistro "${ROS_DISTRO}" -r -y && \
    colcon build \
    --base-paths "${ROSCONFR_WS}/src" \
    --build-base "${ROSCONFR_WS}/build" \
    --install-base "${ROSCONFR_WS}/install" \
    --merge-install && \
    if [[ -f /tmp/rosconfr-colcon-defaults.yaml ]]; then \
    mv /tmp/rosconfr-colcon-defaults.yaml /root/.colcon/defaults.yaml; \
    fi && \
    rm -rf "${ROSCONFR_WS}/build" "${ROSCONFR_WS}/log" && \
    chmod -R a+rX "${ROSCONFR_WS}"

# Every interactive shell in jazzy-webots sources snippets from
# ${ROS_DESKTOP_VNC_DIR}/bashrc.d before it sources the user workspace. Install
# the rosconfr overlay there so a mounted /home/.../ros2_ws remains the last
# overlay loaded in interactive shells.
RUN install -d "${ROS_DESKTOP_VNC_DIR}/bashrc.d" && \
    printf '# Source the prebuilt rosconfr overlay when it is present in the image.\nif [ -f %s/install/local_setup.bash ]; then\n  source %s/install/local_setup.bash\nfi\n' \
    "${ROSCONFR_WS}" "${ROSCONFR_WS}" > "${ROS_DESKTOP_VNC_DIR}/bashrc.d/20-rosconfr.sh" && \
    chmod 644 "${ROS_DESKTOP_VNC_DIR}/bashrc.d/20-rosconfr.sh"
