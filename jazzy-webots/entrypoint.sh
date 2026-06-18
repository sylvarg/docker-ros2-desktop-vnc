#!/usr/bin/env bash

set -Eeuo pipefail

# Runtime knobs exposed to users through `docker run` / `docker compose`.
# Keep these defaults aligned with the image documentation so the container can
# still start with no extra environment variables.
CONTAINER_USER="${USER:-root}"
PASSWORD="${PASSWORD:-${PASSWD:-turtlebot}}"
VNC_NO_PASSWORD="${VNC_NO_PASSWORD:-true}"
TZ="${TZ:-Europe/Paris}"
CONFIG_DIR="${ROS_DESKTOP_VNC_DIR:-/etc/ros-desktop-vnc}"
WEBOTS_BACKEND="${WEBOTS_BACKEND:-bundled}"

# These values are resolved later once the target user is known.
HOME_DIR="/root"
USER_UID="0"

log() {
    printf '[entrypoint] %s\n' "$*"
}

# Accept the common boolean spellings used in Docker environment variables.
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

# Copy a seed file from the image only when the target file does not already
# exist. This preserves user-mounted data and user-edited dotfiles across runs.
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

# Some directories may already exist because they come from Docker volumes or
# were created by root during a previous startup step. Normalize ownership so
# desktop tools, ROS, and Webots all run as the target user.
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

# Webots stores its preferences in INI-like files. Python is used here instead
# of shell text mangling so repeated container starts remain idempotent and do
# not duplicate keys or corrupt sections.
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

# Resolve the runtime Unix user. The image supports both root and a regular
# desktop user because development workflows sometimes mount host workspaces and
# expect shell sessions, GUI tools, and generated files to use a non-root UID.
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
        # When Docker bind-mounts a path below /home/<user>, it may create the
        # parent home directory before the entrypoint runs. Reuse that home
        # directory instead of asking `useradd` to create it again, which would
        # emit a warning on every fresh container start.
        if [[ -d "/home/$CONTAINER_USER" ]]; then
            useradd --home-dir "/home/$CONTAINER_USER" --no-create-home --shell /bin/bash --user-group --groups adm,sudo "$CONTAINER_USER"
        else
            useradd --create-home --home-dir "/home/$CONTAINER_USER" --shell /bin/bash --user-group --groups adm,sudo "$CONTAINER_USER"
        fi
        HOME_DIR="$(getent passwd "$CONTAINER_USER" | cut -d: -f6)"
        USER_UID="$(id -u "$CONTAINER_USER")"
    fi

    # Give the interactive desktop user passwordless sudo. This image is used
    # as a development environment, not as a hardened multi-user system.
    mkdir -p /etc/sudoers.d
    printf '%s ALL=(ALL) NOPASSWD:ALL\n' "$CONTAINER_USER" > "/etc/sudoers.d/90-${CONTAINER_USER}"
    chmod 0440 "/etc/sudoers.d/90-${CONTAINER_USER}"

    echo "$CONTAINER_USER:$PASSWORD" | chpasswd

    # Seed the user home with the image defaults only when those files are not
    # already present. This keeps user state persistent when a home directory is
    # mounted from the host or reused between container starts.
    copy_if_missing "/etc/skel/.bashrc" "$HOME_DIR/.bashrc" "$CONTAINER_USER"
    copy_if_missing "/etc/skel/.profile" "$HOME_DIR/.profile" "$CONTAINER_USER"
    copy_if_missing "/root/.config" "$HOME_DIR/.config" "$CONTAINER_USER"
    copy_if_missing "/root/.gtkrc-2.0" "$HOME_DIR/.gtkrc-2.0" "$CONTAINER_USER"
    copy_if_missing "/root/.asoundrc" "$HOME_DIR/.asoundrc" "$CONTAINER_USER"

    # Pre-create the directories expected by Mesa, colcon, the desktop, and the
    # default ROS workspace layout so first launches do not depend on side
    # effects from GUI applications.
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
    copy_if_missing "$CONFIG_DIR/colcon-defaults.yaml" "$HOME_DIR/.colcon/defaults.yaml" "$CONTAINER_USER"
    for desktop_file in /usr/local/share/ros-desktop-vnc/desktop/*.desktop; do
        copy_if_missing "$desktop_file" "$HOME_DIR/Desktop/$(basename "$desktop_file")" "$CONTAINER_USER"
    done

    # Audio device permissions vary depending on the host runtime. Best effort
    # is enough here because sound support is optional for most workflows.
    if [[ -d /dev/snd ]]; then
        chgrp -R adm /dev/snd || true
    fi
}

# Graphical sessions expect XDG_RUNTIME_DIR to exist and be writable by the
# logged-in user. Containers often start without it, so we create it ourselves.
configure_runtime_dir() {
    local runtime_dir="/run/user/$USER_UID"
    install -d -m 700 -o "$CONTAINER_USER" -g "$CONTAINER_USER" "$runtime_dir"
}

# Prepare the TigerVNC runtime files in the user's home directory. The config
# files are copied from the image so they can still be customized by users in a
# persistent home volume.
configure_vnc() {
    local vnc_password="${VNC_PASSWORD:-$PASSWORD}"
    local vnc_dir="$HOME_DIR/.vnc"
    local xstartup_path="$vnc_dir/xstartup"
    local vncrun_path="$vnc_dir/vnc_run.sh"

    mkdir -p "$vnc_dir"
    if is_true "$VNC_NO_PASSWORD"; then
        rm -f "$vnc_dir/passwd"
        log "VNC authentication disabled"
    else
        printf '%s\n' "$vnc_password" | vncpasswd -f > "$vnc_dir/passwd"
        chmod 600 "$vnc_dir/passwd"
    fi

    copy_if_missing "$CONFIG_DIR/xstartup.sh" "$xstartup_path" "$CONTAINER_USER"
    copy_if_missing "$CONFIG_DIR/vnc_run.sh" "$vncrun_path" "$CONTAINER_USER"
    chmod 755 "$xstartup_path" "$vncrun_path"
    ensure_owned "$CONTAINER_USER" "$vnc_dir"
}

# `rosdep init` is performed at build time as root. At runtime we only need to
# copy the resulting cache into the interactive user's home so `rosdep update`
# and package resolution work out of the box.
configure_rosdep() {
    local ros_dir="$HOME_DIR/.ros"

    mkdir -p "$ros_dir"
    if [[ -d /root/.ros/rosdep && ! -e "$ros_dir/rosdep" ]]; then
        cp -a /root/.ros/rosdep "$ros_dir/rosdep"
    fi
    ensure_owned "$CONTAINER_USER" "$ros_dir"
}

# Seed the runtime home with any SSH material baked into the image. The copy is
# intentionally non-destructive so a mounted home directory or user-managed SSH
# config keeps taking precedence over the image defaults.
configure_ssh() {
    local seed_dir="/etc/skel/.ssh"
    local ssh_dir="$HOME_DIR/.ssh"
    local seed_path target_path key_path

    [[ -d "$seed_dir" ]] || return 0

    install -d -m 700 "$ssh_dir"

    shopt -s nullglob
    for seed_path in "$seed_dir"/*; do
        target_path="$ssh_dir/$(basename "$seed_path")"
        copy_if_missing "$seed_path" "$target_path" "$CONTAINER_USER"
    done
    shopt -u nullglob

    chmod 700 "$ssh_dir"

    if [[ -f "$ssh_dir/config" ]]; then
        chmod 600 "$ssh_dir/config"
    fi

    shopt -s nullglob
    for key_path in "$ssh_dir"/id_*; do
        if [[ "$key_path" == *.pub ]]; then
            chmod 644 "$key_path"
        else
            chmod 600 "$key_path"
        fi
    done
    shopt -u nullglob

    ensure_owned "$CONTAINER_USER" "$ssh_dir"
}

# When Webots runs on the host, `webots_ros2` expects a shared host/container
# folder described as "<host path>:<container path>". The entrypoint only owns
# the container side of that contract, so it ensures the target directory exists
# with the correct permissions before the first launch file runs.
configure_webots_shared_folder() {
    local shared_spec="${WEBOTS_SHARED_FOLDER:-}"
    local container_shared_dir

    # Absence of a shared folder is valid for the bundled backend and should
    # not abort the entrypoint under `set -e`.
    [[ -n "$shared_spec" ]] || return 0

    container_shared_dir="${shared_spec##*:}"
    if [[ "$container_shared_dir" == "$shared_spec" ]]; then
        log "WEBOTS_SHARED_FOLDER has no container path suffix: $shared_spec"
        return
    fi

    mkdir -p "$container_shared_dir"
    ensure_owned "$CONTAINER_USER" "$container_shared_dir"

    if [[ "$WEBOTS_BACKEND" == "external" ]]; then
        log "using external Webots backend with shared folder: $shared_spec"
    fi
}

# In bundled mode the container owns the local Linux Webots installation, so we
# can pre-seed its user preferences. In external mode the simulator runs on the
# host and these files would be meaningless inside the container.
configure_webots_preferences() {
    local version_file="/usr/local/webots/resources/version.txt"
    local preferences_dir preferences_file webots_version

    if [[ "$WEBOTS_BACKEND" != "bundled" ]]; then
        log "skipping local Webots preference setup for backend: $WEBOTS_BACKEND"
        return
    fi

    # Missing local Webots files simply means there is nothing to configure.
    [[ -x /usr/local/bin/webots && -f "$version_file" ]] || return 0

    webots_version="$(<"$version_file")"
    [[ -n "$webots_version" ]] || return 0

    preferences_dir="$HOME_DIR/.config/Cyberbotics"
    preferences_file="$preferences_dir/Webots-${webots_version}.conf"

    mkdir -p "$preferences_dir"
    ensure_owned "$CONTAINER_USER" "$HOME_DIR/.config" "$preferences_dir"
    copy_if_missing "$CONFIG_DIR/webots-default.conf" "$preferences_file" "$CONTAINER_USER"

    set_ini_value "$preferences_file" "%General" "checkWebotsUpdateOnStartup" "true"
    set_ini_value "$preferences_file" "%General" "startupMode" "Real-time"
    set_ini_value "$preferences_file" "%General" "telemetry" "false"
    set_ini_value "$preferences_file" "%General" "theme" "webots_classic.qss"
    set_ini_value "$preferences_file" "Internal" "firstLaunch" "false"

    ensure_owned "$CONTAINER_USER" "$preferences_dir" "$preferences_file"
}

# A small template is easier to maintain than generating the whole supervisor
# file in shell. We only substitute the runtime-dependent values here.
configure_supervisor() {
    local vncrun_path="$HOME_DIR/.vnc/vnc_run.sh"
    local template_path="$CONFIG_DIR/supervisord.conf.template"

    sed \
        -e "s|__CONTAINER_USER__|$CONTAINER_USER|g" \
        -e "s|__VNC_RUN_PATH__|$vncrun_path|g" \
        "$template_path" > /etc/supervisor/conf.d/ros-desktop-vnc.conf
}

# Startup order matters: the user and home directory must exist before VNC,
# rosdep, or Webots setup can touch per-user files.
main() {
    configure_timezone
    ensure_user
    configure_runtime_dir
    configure_vnc
    configure_rosdep
    configure_ssh
    configure_webots_shared_folder
    configure_webots_preferences
    configure_supervisor

    # Export the final runtime environment inherited by shells, launch files,
    # and the supervised desktop processes.
    export HOME="$HOME_DIR"
    export USER="$CONTAINER_USER"
    export VNC_NO_PASSWORD
    export TZ
    export WEBOTS_BACKEND
    unset PASSWORD PASSWD VNC_PASSWORD

    # `tini` stays PID 1 to reap zombies and forward signals cleanly, while
    # `supervisord` keeps the desktop stack alive.
    exec /usr/bin/tini -- supervisord -n -c /etc/supervisor/supervisord.conf
}

main "$@"
