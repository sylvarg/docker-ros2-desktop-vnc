#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TB3_DIR="$(cd -- "$SCRIPT_DIR/../jazzy-webots-tb3" && pwd)"
TB3_KEY="$TB3_DIR/ssh/id_ed25519_tb3_tp"

if [[ -f "$TB3_KEY" ]] || ! docker image inspect ros2-desktop-vnc:jazzy-webots-tb3 >/dev/null 2>&1; then
    # TB3 handles key detection, the BuildKit secret and fingerprint caching.
    bash "$TB3_DIR/build.sh"
fi

docker build \
    -t ros2-desktop-vnc:jazzy-webots-tb3-ned2 \
    "$@" \
    "$SCRIPT_DIR"
