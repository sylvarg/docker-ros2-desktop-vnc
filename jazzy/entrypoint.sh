#!/usr/bin/env bash

set -Eeuo pipefail

CONTAINER_USER="${USER:-root}"
PASSWORD="${PASSWORD:-${PASSWD:-turtlebot}}"
HOME_DIR="/root"

log() {
    printf '[entrypoint] %s\n' "$*"
}

copy_if_missing() {
    local source_path="$1"
    local target_path="$2"
    local owner="$3"

    if [[ -e "$source_path" && ! -e "$target_path" ]]; then
        mkdir -p "$(dirname "$target_path")"
        cp -a "$source_path" "$target_path"
        chown -R "${owner}:${owner}" "$target_path"
    fi
}

ensure_user() {
    if [[ "$CONTAINER_USER" == "root" ]]; then
        HOME_DIR="/root"
        return
    fi

    if id -u "$CONTAINER_USER" >/dev/null 2>&1; then
        HOME_DIR="$(getent passwd "$CONTAINER_USER" | cut -d: -f6)"
        log "using existing user: $CONTAINER_USER"
    else
        log "creating user: $CONTAINER_USER"
        useradd --create-home --shell /bin/bash --user-group --groups adm,sudo "$CONTAINER_USER"
        HOME_DIR="$(getent passwd "$CONTAINER_USER" | cut -d: -f6)"
    fi

    mkdir -p /etc/sudoers.d
    printf '%s ALL=(ALL) NOPASSWD:ALL\n' "$CONTAINER_USER" > "/etc/sudoers.d/90-${CONTAINER_USER}"
    chmod 0440 "/etc/sudoers.d/90-${CONTAINER_USER}"

    echo "$CONTAINER_USER:$PASSWORD" | chpasswd

    copy_if_missing "/etc/skel/.bashrc" "$HOME_DIR/.bashrc" "$CONTAINER_USER"
    copy_if_missing "/etc/skel/.profile" "$HOME_DIR/.profile" "$CONTAINER_USER"
    copy_if_missing "/root/.config" "$HOME_DIR/.config" "$CONTAINER_USER"
    copy_if_missing "/root/.gtkrc-2.0" "$HOME_DIR/.gtkrc-2.0" "$CONTAINER_USER"
    copy_if_missing "/root/.asoundrc" "$HOME_DIR/.asoundrc" "$CONTAINER_USER"

    mkdir -p "$HOME_DIR/.colcon" "$HOME_DIR/Desktop" "$HOME_DIR/ros2_ws/src"
    chown "$CONTAINER_USER:$CONTAINER_USER" "$HOME_DIR/.colcon" "$HOME_DIR/Desktop"
    copy_if_missing "/etc/ros-desktop-vnc/colcon-defaults.yaml" "$HOME_DIR/.colcon/defaults.yaml" "$CONTAINER_USER"
    for desktop_file in /usr/local/share/ros-desktop-vnc/desktop/*.desktop; do
        copy_if_missing "$desktop_file" "$HOME_DIR/Desktop/$(basename "$desktop_file")" "$CONTAINER_USER"
    done
    if [[ -d /dev/snd ]]; then
        chgrp -R adm /dev/snd || true
    fi
}

configure_vnc() {
    local vnc_password="${VNC_PASSWORD:-$PASSWORD}"
    local vnc_dir="$HOME_DIR/.vnc"
    local xstartup_path="$vnc_dir/xstartup"
    local vncrun_path="$vnc_dir/vnc_run.sh"

    mkdir -p "$vnc_dir"
    printf '%s\n' "$vnc_password" | vncpasswd -f > "$vnc_dir/passwd"
    chmod 600 "$vnc_dir/passwd"

    cat > "$xstartup_path" <<'EOF'
#!/bin/sh
unset DBUS_SESSION_BUS_ADDRESS
mate-session
EOF
    chmod 755 "$xstartup_path"

    cat > "$vncrun_path" <<'EOF'
#!/usr/bin/env bash
set -e

rm -f /tmp/.X1-lock /tmp/.X11-unix/X1

if [[ "$(uname -m)" == "aarch64" ]]; then
    export LD_PRELOAD=/lib/aarch64-linux-gnu/libgcc_s.so.1
fi

exec vncserver :1 -fg -geometry 1920x1080 -depth 24
EOF
    chmod 755 "$vncrun_path"
    chown -R "$CONTAINER_USER:$CONTAINER_USER" "$vnc_dir"
}

configure_rosdep() {
    local ros_dir="$HOME_DIR/.ros"

    mkdir -p "$ros_dir"
    if [[ -d /root/.ros/rosdep && ! -e "$ros_dir/rosdep" ]]; then
        cp -a /root/.ros/rosdep "$ros_dir/rosdep"
    fi
    chown -R "$CONTAINER_USER:$CONTAINER_USER" "$ros_dir"
}

configure_supervisor() {
    local vncrun_path="$HOME_DIR/.vnc/vnc_run.sh"

    cat > /etc/supervisor/conf.d/ros-desktop-vnc.conf <<EOF
[supervisord]
nodaemon=true
user=root

[program:vnc]
command=gosu $CONTAINER_USER bash $vncrun_path
priority=10
autorestart=true

[program:novnc]
command=gosu $CONTAINER_USER bash -lc "websockify --web=/usr/lib/novnc 6080 localhost:5901"
priority=20
autorestart=true
EOF
}

main() {
    ensure_user
    configure_vnc
    configure_rosdep
    configure_supervisor

    export HOME="$HOME_DIR"
    export USER="$CONTAINER_USER"
    unset PASSWORD PASSWD VNC_PASSWORD

    exec /usr/bin/tini -- supervisord -n -c /etc/supervisor/supervisord.conf
}

main "$@"
