#!/usr/bin/env bash

set -Eeuo pipefail

# This helper starts the upstream Webots local simulation server on macOS so a
# Linux ROS environment running in Docker can ask the native Webots.app process
# to open worlds and spawn controllers.
#
# Required inputs:
# - WEBOTS_HOME: path to the native macOS Webots installation
# - WEBOTS_SERVER_SCRIPT: path to `local_simulation_server.py` from
#   https://github.com/cyberbotics/webots-server
#
# Optional inputs:
# - WEBOTS_SHARED_HOST_DIR: host directory also mounted in the container and
#   exported there through WEBOTS_SHARED_FOLDER.

# Default path for Webots.app on macOS, should be adapted accordingly
WEBOTS_HOME="${WEBOTS_HOME:-/Applications/Webots.app}" 
WEBOTS_SERVER_SCRIPT="${WEBOTS_SERVER_SCRIPT:-${1:-}}"
WEBOTS_SHARED_HOST_DIR="${WEBOTS_SHARED_HOST_DIR:-/tmp/ros2-desktop-vnc-webots-shared}"

if [[ ! -d "$WEBOTS_HOME" ]]; then
    printf 'Webots.app not found at: %s\n' "$WEBOTS_HOME" >&2
    printf 'Set WEBOTS_HOME to your native macOS Webots installation.\n' >&2
    exit 1
fi

if [[ -z "$WEBOTS_SERVER_SCRIPT" ]]; then
    printf 'Missing WEBOTS_SERVER_SCRIPT.\n' >&2
    printf 'Example:\n' >&2
    printf '  git clone https://github.com/cyberbotics/webots-server /tmp/webots-server\n' >&2
    printf '  WEBOTS_SERVER_SCRIPT=/tmp/webots-server/local_simulation_server.py %s\n' "$0" >&2
    exit 1
fi

if [[ ! -f "$WEBOTS_SERVER_SCRIPT" ]]; then
    printf 'local_simulation_server.py not found at: %s\n' "$WEBOTS_SERVER_SCRIPT" >&2
    exit 1
fi

mkdir -p "$WEBOTS_SHARED_HOST_DIR"

export WEBOTS_HOME

printf 'Starting native Webots host server\n'
printf '  WEBOTS_HOME=%s\n' "$WEBOTS_HOME"
printf '  WEBOTS_SERVER_SCRIPT=%s\n' "$WEBOTS_SERVER_SCRIPT"
printf '  WEBOTS_SHARED_HOST_DIR=%s\n' "$WEBOTS_SHARED_HOST_DIR"

exec python3 "$WEBOTS_SERVER_SCRIPT"
