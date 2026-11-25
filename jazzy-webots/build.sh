#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
VARIANT=external
case "${1:-}" in
    external|embedded)
        VARIANT=$1
        shift
        ;;
    -h|--help)
        printf 'Usage: bash build.sh [external|embedded] [docker build arguments...]\n'
        exit 0
        ;;
    ''|-*) ;;
    *)
        printf 'Unknown Webots variant: %s (expected external or embedded)\n' "$1" >&2
        exit 2
        ;;
esac

BACKEND=external
if [[ "$VARIANT" == embedded ]]; then
    BACKEND=bundled
    set -- "$@" --platform linux/amd64
fi

# Extra tags/options are accepted; the selected backend and embedded platform
# are applied last so the resulting standard tag always describes the image.
docker build \
    "$@" \
    --build-arg "WEBOTS_BACKEND=$BACKEND" \
    -t "ros2-desktop-vnc:jazzy-webots-$VARIANT" \
    "$SCRIPT_DIR"
