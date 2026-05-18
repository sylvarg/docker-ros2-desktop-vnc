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

# Every interactive shell in jazzy-webots already sources
# ${ROS_DESKTOP_VNC_DIR}/bashrc.sh. Appending the rosconfr overlay there makes
# the package immediately available to root and to the runtime desktop user,
# without changing the base image.
RUN printf '\n# Source the prebuilt rosconfr overlay when it is present in the image.\nif [ -f %s/install/local_setup.bash ]; then\n  source %s/install/local_setup.bash\nfi\n' \
    "${ROSCONFR_WS}" "${ROSCONFR_WS}" >> "${ROS_DESKTOP_VNC_DIR}/bashrc.sh"

WORKDIR ${ROSCONFR_WS}
