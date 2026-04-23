#!/usr/bin/env bash

set -Eeuo pipefail

CONTAINER_USER="${USER:-root}"
PASSWORD="${PASSWORD:-${PASSWD:-turtlebot}}"
VNC_NO_PASSWORD="${VNC_NO_PASSWORD:-true}"
TZ="${TZ:-Europe/Paris}"
HOME_DIR="/root"
USER_UID="0"

log() {
    printf '[entrypoint] %s\n' "$*"
}

is_true() {
    case "${1,,}" in
        1|true|yes|on)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
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

ensure_owned() {
    local owner="$1"
    shift

    local path
    for path in "$@"; do
        if [[ -e "$path" ]]; then
            chown -R "${owner}:${owner}" "$path"
        fi
    done
}

set_ini_value() {
    local file_path="$1"
    local section="$2"
    local key="$3"
    local value="$4"

    python3 - "$file_path" "$section" "$key" "$value" <<'PY'
from pathlib import Path
import sys

file_path, section, key, value = sys.argv[1:]
path = Path(file_path)
header = f'[{section}]'
lines = path.read_text().splitlines() if path.exists() else []

out = []
in_section = False
section_found = False
key_set = False

for line in lines:
    stripped = line.strip()
    if stripped.startswith('[') and stripped.endswith(']'):
        if in_section and not key_set:
            out.append(f'{key}={value}')
            key_set = True
        in_section = stripped == header
        section_found = section_found or in_section
        out.append(line)
        continue
    if in_section and stripped.startswith(f'{key}='):
        out.append(f'{key}={value}')
        key_set = True
    else:
        out.append(line)

if section_found:
    if in_section and not key_set:
        out.append(f'{key}={value}')
else:
    if out and out[-1] != '':
        out.append('')
    out.extend([header, f'{key}={value}'])

path.write_text('\n'.join(out) + '\n')
PY
}

configure_timezone() {
    local zoneinfo_path="/usr/share/zoneinfo/$TZ"

    if [[ -f "$zoneinfo_path" ]]; then
        ln -snf "$zoneinfo_path" /etc/localtime
        printf '%s\n' "$TZ" > /etc/timezone
        log "timezone set to $TZ"
    else
        log "timezone not found: $TZ"
    fi
}

ensure_user() {
    if [[ "$CONTAINER_USER" == "root" ]]; then
        HOME_DIR="/root"
        USER_UID="$(id -u root)"
        return
    fi

    if id -u "$CONTAINER_USER" >/dev/null 2>&1; then
        HOME_DIR="$(getent passwd "$CONTAINER_USER" | cut -d: -f6)"
        USER_UID="$(id -u "$CONTAINER_USER")"
        log "using existing user: $CONTAINER_USER"
    else
        log "creating user: $CONTAINER_USER"
        useradd --create-home --shell /bin/bash --user-group --groups adm,sudo "$CONTAINER_USER"
        HOME_DIR="$(getent passwd "$CONTAINER_USER" | cut -d: -f6)"
        USER_UID="$(id -u "$CONTAINER_USER")"
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

    mkdir -p "$HOME_DIR/.cache/mesa_shader_cache" "$HOME_DIR/.colcon" "$HOME_DIR/Desktop" "$HOME_DIR/ros2_ws/src"
    chown "$CONTAINER_USER:$CONTAINER_USER" \
        "$HOME_DIR" \
        "$HOME_DIR/.cache" \
        "$HOME_DIR/.cache/mesa_shader_cache" \
        "$HOME_DIR/.colcon" \
        "$HOME_DIR/Desktop" \
        "$HOME_DIR/ros2_ws"
    ensure_owned "$CONTAINER_USER" \
        "$HOME_DIR/.cache" \
        "$HOME_DIR/.config" \
        "$HOME_DIR/.local" \
        "$HOME_DIR/.colcon" \
        "$HOME_DIR/Desktop" \
        "$HOME_DIR/ros2_ws"
    copy_if_missing "/etc/ros-desktop-vnc/colcon-defaults.yaml" "$HOME_DIR/.colcon/defaults.yaml" "$CONTAINER_USER"
    for desktop_file in /usr/local/share/ros-desktop-vnc/desktop/*.desktop; do
        copy_if_missing "$desktop_file" "$HOME_DIR/Desktop/$(basename "$desktop_file")" "$CONTAINER_USER"
    done
    if [[ -d /dev/snd ]]; then
        chgrp -R adm /dev/snd || true
    fi
}

configure_runtime_dir() {
    local runtime_dir="/run/user/$USER_UID"

    install -d -m 700 -o "$CONTAINER_USER" -g "$CONTAINER_USER" "$runtime_dir"
}

configure_vnc() {
    local vnc_password="${VNC_PASSWORD:-$PASSWORD}"
    local vnc_dir="$HOME_DIR/.vnc"
    local xstartup_path="$vnc_dir/xstartup"
    local vncrun_path="$vnc_dir/vnc_run.sh"
    local config_dir="/etc/ros-desktop-vnc"

    mkdir -p "$vnc_dir"
    if is_true "$VNC_NO_PASSWORD"; then
        rm -f "$vnc_dir/passwd"
        log "VNC authentication disabled"
    else
        printf '%s\n' "$vnc_password" | vncpasswd -f > "$vnc_dir/passwd"
        chmod 600 "$vnc_dir/passwd"
    fi

    copy_if_missing "$config_dir/xstartup.sh" "$xstartup_path" "$CONTAINER_USER"
    copy_if_missing "$config_dir/vnc_run.sh" "$vncrun_path" "$CONTAINER_USER"
    chmod 755 "$xstartup_path" "$vncrun_path"
    ensure_owned "$CONTAINER_USER" "$vnc_dir"
}

configure_rosdep() {
    local ros_dir="$HOME_DIR/.ros"

    mkdir -p "$ros_dir"
    if [[ -d /root/.ros/rosdep && ! -e "$ros_dir/rosdep" ]]; then
        cp -a /root/.ros/rosdep "$ros_dir/rosdep"
    fi
    ensure_owned "$CONTAINER_USER" "$ros_dir"
}

configure_webots_preferences() {
    local version_file="/usr/local/webots/resources/version.txt"
    local preferences_dir preferences_file webots_version

    [[ -x /usr/local/bin/webots && -f "$version_file" ]] || return

    webots_version="$(<"$version_file")"
    [[ -n "$webots_version" ]] || return

    preferences_dir="$HOME_DIR/.config/Cyberbotics"
    preferences_file="$preferences_dir/Webots-${webots_version}.conf"

    mkdir -p "$preferences_dir"
    ensure_owned "$CONTAINER_USER" "$HOME_DIR/.config" "$preferences_dir"
    copy_if_missing "/etc/ros-desktop-vnc/webots-default.conf" "$preferences_file" "$CONTAINER_USER"

    set_ini_value "$preferences_file" "%General" "checkWebotsUpdateOnStartup" "true"
    set_ini_value "$preferences_file" "%General" "startupMode" "Real-time"
    set_ini_value "$preferences_file" "%General" "telemetry" "false"
    set_ini_value "$preferences_file" "%General" "theme" "webots_classic.qss"
    set_ini_value "$preferences_file" "Internal" "firstLaunch" "false"

    ensure_owned "$CONTAINER_USER" "$preferences_dir" "$preferences_file"
}

configure_supervisor() {
    local vncrun_path="$HOME_DIR/.vnc/vnc_run.sh"
    local template_path="/etc/ros-desktop-vnc/supervisord.conf.template"

    sed \
        -e "s|__CONTAINER_USER__|$CONTAINER_USER|g" \
        -e "s|__VNC_RUN_PATH__|$vncrun_path|g" \
        "$template_path" > /etc/supervisor/conf.d/ros-desktop-vnc.conf
}

main() {
    configure_timezone
    ensure_user
    configure_runtime_dir
    configure_vnc
    configure_rosdep
    configure_webots_preferences
    configure_supervisor

    export HOME="$HOME_DIR"
    export USER="$CONTAINER_USER"
    export VNC_NO_PASSWORD
    export TZ
    unset PASSWORD PASSWD VNC_PASSWORD

    exec /usr/bin/tini -- supervisord -n -c /etc/supervisor/supervisord.conf
}

main "$@"
