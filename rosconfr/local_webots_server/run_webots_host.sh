#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SERVER_SCRIPT="$SCRIPT_DIR/local_simulation_server.py"

usage() {
    cat >&2 <<'EOF'
Usage:
  run_webots_host.sh --env-file <path> [server-port]

The env file must define at least WEBOTS_SHARED_HOST_DIR.
It can also define WEBOTS_HOME.
EOF
}

parse_env_file() {
    env_file=$1
    while IFS= read -r line || [ -n "$line" ]; do
        line=$(printf '%s' "$line" | tr -d '\r')
        trimmed_line=$(printf '%s' "$line" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')

        case "$trimmed_line" in
            ''|'#'*)
                continue
                ;;
        esac

        case "$line" in
            *=*)
                key=${line%%=*}
                value=${line#*=}
                ;;
            *)
                continue
                ;;
        esac

        key=$(printf '%s' "$key" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
        value=$(printf '%s' "$value" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')

        case "$value" in
            \"*\")
                value=${value#\"}
                value=${value%\"}
                ;;
            \'*\')
                value=${value#\'}
                value=${value%\'}
                ;;
        esac

        case "$key" in
            WEBOTS_HOME)
                WEBOTS_HOME=$value
                export WEBOTS_HOME
                ;;
            WEBOTS_SHARED_HOST_DIR)
                WEBOTS_SHARED_HOST_DIR=$value
                export WEBOTS_SHARED_HOST_DIR
                ;;
        esac
    done < "$env_file"
}

if [ "$#" -lt 2 ] || [ "$1" != "--env-file" ]; then
    usage
    exit 1
fi

ENV_FILE="$2"
shift 2

if [ ! -f "$ENV_FILE" ]; then
    printf 'Env file not found: %s\n' "$ENV_FILE" >&2
    exit 1
fi

parse_env_file "$ENV_FILE"

if [ "$(uname -s)" = "Darwin" ]; then
    default_webots_home="/Applications/Webots.app"
else
    default_webots_home="/usr/local/webots"
fi

WEBOTS_HOME="${WEBOTS_HOME:-$default_webots_home}"

if [ -z "${WEBOTS_SHARED_HOST_DIR:-}" ]; then
    printf 'WEBOTS_SHARED_HOST_DIR is required in %s\n' "$ENV_FILE" >&2
    exit 1
fi

if [ ! -f "$SERVER_SCRIPT" ]; then
    printf 'Repository-local Webots server script not found: %s\n' "$SERVER_SCRIPT" >&2
    exit 1
fi

if [ ! -d "$WEBOTS_HOME" ]; then
    printf 'Webots installation not found at: %s\n' "$WEBOTS_HOME" >&2
    printf 'Set WEBOTS_HOME in the env file or your shell environment.\n' >&2
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
printf '  ENV_FILE=%s\n' "$ENV_FILE"
printf '  WEBOTS_HOME=%s\n' "$WEBOTS_HOME"
printf '  WEBOTS_SHARED_HOST_DIR=%s\n' "$WEBOTS_SHARED_HOST_DIR"

exec python3 "$SERVER_SCRIPT" "$@"
