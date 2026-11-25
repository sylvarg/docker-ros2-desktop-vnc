#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TB3_KEY="$SCRIPT_DIR/ssh/id_ed25519_tb3_tp"

# An explicit TB3 secret takes precedence over the conventional local key.
EXPLICIT_TB3_KEY=false
NEXT_IS_SECRET=false
for argument in "$@"; do
    secret_spec=
    if [[ "$NEXT_IS_SECRET" == true ]]; then
        secret_spec=$argument
        NEXT_IS_SECRET=false
    elif [[ "$argument" == --secret ]]; then
        NEXT_IS_SECRET=true
    elif [[ "$argument" == --secret=* ]]; then
        secret_spec=${argument#--secret=}
    fi
    if [[ ",$secret_spec," == *,id=tb3_ssh_key,* ]]; then
        EXPLICIT_TB3_KEY=true
    fi
done

if [[ "$EXPLICIT_TB3_KEY" == false && -f "$TB3_KEY" ]]; then
    fingerprint="$(ssh-keygen -y -f "$TB3_KEY" | ssh-keygen -lf - | awk '{print $2}')"
    set -- --secret "id=tb3_ssh_key,src=$TB3_KEY" \
        --build-arg "TB3_SSH_KEY_FINGERPRINT=$fingerprint" "$@"
    printf 'Using lab SSH key: %s\n' "$TB3_KEY"
fi

# Build the shared external parent from this checkout, using its standard tag.
bash "$SCRIPT_DIR/../jazzy-webots/build.sh" external

# Extra arguments, including an optional --secret, apply only to the TB3 image.
docker build \
    -t ros2-desktop-vnc:jazzy-webots-tb3 \
    "$@" \
    "$SCRIPT_DIR"
