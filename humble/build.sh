#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# Keep the historical Compose image name as an additional local tag.
docker build \
    -t ros2-desktop-vnc:humble \
    -t sylar/ros2-desktop-vnc:humble \
    "$@" \
    "$SCRIPT_DIR"
