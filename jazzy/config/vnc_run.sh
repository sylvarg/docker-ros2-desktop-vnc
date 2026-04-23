#!/usr/bin/env bash
set -e

rm -f /tmp/.X1-lock /tmp/.X11-unix/X1

if [[ "$(uname -m)" == "aarch64" ]]; then
    export LD_PRELOAD=/lib/aarch64-linux-gnu/libgcc_s.so.1
fi

export XDG_RUNTIME_DIR="/run/user/$(id -u)"

security_args=()
case "${VNC_NO_PASSWORD:-true}" in
    1|true|TRUE|yes|YES|on|ON)
        security_args=(-SecurityTypes None)
        ;;
    *)
        security_args=(-rfbauth "$HOME/.vnc/passwd")
        ;;
esac

exec vncserver :1 -fg -geometry 1920x1080 -depth 24 "${security_args[@]}"
