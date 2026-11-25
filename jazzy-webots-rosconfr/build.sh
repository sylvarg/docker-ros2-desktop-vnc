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

# Match the parent's architecture if an external cross-build is requested.
# Other options (secrets, ROSCONFR_REF, cache flags, tags) apply to ROSCon only.
PARENT_ARGUMENTS=("$VARIANT")
NEXT_IS_PLATFORM=false
for argument in "$@"; do
    if [[ "$NEXT_IS_PLATFORM" == true ]]; then
        PARENT_ARGUMENTS+=(--platform "$argument")
        NEXT_IS_PLATFORM=false
    elif [[ "$argument" == --platform ]]; then
        NEXT_IS_PLATFORM=true
    elif [[ "$argument" == --platform=* ]]; then
        PARENT_ARGUMENTS+=("$argument")
    fi
done
if [[ "$NEXT_IS_PLATFORM" == true ]]; then
    printf '%s\n' '--platform requires a value.' >&2
    exit 2
fi

bash "$SCRIPT_DIR/../jazzy-webots/build.sh" "${PARENT_ARGUMENTS[@]}"

if [[ "$VARIANT" == embedded ]]; then
    set -- "$@" --platform linux/amd64
fi

docker build \
    "$@" \
    --build-arg BASE_IMAGE_REPOSITORY=ros2-desktop-vnc \
    --build-arg "WEBOTS_BACKEND=$VARIANT" \
    -t ros2-desktop-vnc:jazzy-webots-rosconfr \
    "$SCRIPT_DIR"
