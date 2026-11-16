#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# Keep the parent local to this variant and always build it from this checkout.
docker build \
    --build-arg WEBOTS_BACKEND=external \
    -t ros2-desktop-vnc:jazzy-webots-tb3-base \
    "$SCRIPT_DIR/../jazzy-webots"

# Extra arguments, including an optional --secret, apply only to the TB3 image.
docker build \
    -t ros2-desktop-vnc:jazzy-webots-tb3 \
    "$@" \
    "$SCRIPT_DIR"
