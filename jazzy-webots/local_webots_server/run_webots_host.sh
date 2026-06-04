#!/usr/bin/env bash

set -Eeuo pipefail

# This launcher starts the repository-local Python host server on Unix-like
# systems. The Python script contains the cross-platform Webots server logic;
# this shell wrapper only handles host-specific bootstrap tasks that are more
# naturally expressed in the shell:
# - choose a default WEBOTS_HOME based on the host OS
# - verify that the native Webots installation exists
# - create the shared directory used by Docker and Webots
# - verify that `python3` is available
# - export the environment variables consumed by the Python server
#
# Any extra arguments are forwarded verbatim to `local_simulation_server.py`.
# This keeps parity with the original upstream server, whose first optional
# argument is the TCP port number.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_SCRIPT="$SCRIPT_DIR/local_simulation_server.py"

if [[ "$(uname -s)" == "Darwin" ]]; then
    default_webots_home="/Applications/Webots.app"
else
    default_webots_home="/usr/local/webots"
fi

WEBOTS_HOME="${WEBOTS_HOME:-$default_webots_home}"
WEBOTS_SHARED_HOST_DIR="${WEBOTS_SHARED_HOST_DIR:-/tmp/ros2-desktop-vnc-webots-shared}"

if [[ ! -f "$SERVER_SCRIPT" ]]; then
    printf 'Repository-local Webots server script not found: %s\n' "$SERVER_SCRIPT" >&2
    exit 1
fi

if [[ ! -d "$WEBOTS_HOME" ]]; then
    printf 'Webots installation not found at: %s\n' "$WEBOTS_HOME" >&2
    printf 'Set WEBOTS_HOME to your native host Webots installation.\n' >&2
    exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
    printf 'python3 was not found on this host.\n' >&2
    printf 'Install Python 3, then re-run this launcher.\n' >&2
    exit 1
fi

mkdir -p "$WEBOTS_SHARED_HOST_DIR"

export WEBOTS_HOME
export WEBOTS_SHARED_HOST_DIR

printf 'Launching repository-local Webots host server...\n'

exec python3 "$SERVER_SCRIPT" "$@"
