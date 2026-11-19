#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TB3_DIR="$(cd -- "$SCRIPT_DIR/../jazzy-webots-tb3" && pwd)"
TB3_KEY="$TB3_DIR/ssh/id_ed25519_tb3_tp"

if [[ -f "$TB3_KEY" ]]; then
    fingerprint="$(ssh-keygen -y -f "$TB3_KEY" | ssh-keygen -lf - | awk '{print $2}')"
    bash "$TB3_DIR/build.sh" \
        --secret "id=tb3_ssh_key,src=$TB3_KEY" \
        --build-arg "TB3_SSH_KEY_FINGERPRINT=$fingerprint"
elif ! docker image inspect ros2-desktop-vnc:jazzy-webots-tb3 >/dev/null 2>&1; then
    bash "$TB3_DIR/build.sh"
fi

docker build \
    -t ros2-desktop-vnc:jazzy-webots-tb3-ned2 \
    "$@" \
    "$SCRIPT_DIR"
