#!/usr/bin/env python3
"""Repository-local Webots host server used by the external Docker workflow.

This script intentionally replaces the previous "download upstream, then patch
it on Windows" approach with a single implementation that is versioned in this
repository and shared by Linux, macOS, and Windows launchers.

The protocol stays deliberately close to Cyberbotics' original
`local_simulation_server.py` so that `webots_ros2_driver` can keep talking to a
simple TCP server:

1. listen on a TCP port, defaulting to 2000
2. receive a command line from the Docker-side client
3. replace the Webots executable with a native host path when needed
4. launch Webots on the host
5. keep the TCP connection open until Webots exits or the client disconnects

The script uses only Python's standard library so that the Windows helper can
continue relying on a minimal Python installation path.
"""

from __future__ import annotations

import os
import shlex
import socket
import subprocess
import sys
from pathlib import Path
from typing import Iterable


HOST = ""
DEFAULT_PORT = 2000
BUFFER_SIZE = 1024


def close_connection(connection: socket.socket, message: str) -> None:
    """Send an error message to the client and close the TCP connection."""
    connection.sendall(message.encode("utf-8"))
    print(message, file=sys.stderr)
    connection.close()


def parse_command(payload: bytes) -> list[str]:
    """Parse the incoming command line from the Webots ROS client.

    The upstream server used a plain `split(' ')`, which is fragile when paths
    contain spaces. Here we prefer `shlex.split` so quoted paths remain intact.
    We still keep the parsing intentionally simple so the behavior stays close
    to the original helper.
    """
    raw_command = payload.decode("utf-8").strip()
    if not raw_command:
        return []

    # `posix=False` avoids treating backslashes in Windows paths as escapes.
    command = shlex.split(raw_command, posix=False)
    return [argument.strip('"') for argument in command]


def looks_like_webots_executable(command: str) -> bool:
    """Return True when the requested program clearly targets Webots."""
    executable_name = os.path.basename(command).lower()
    return executable_name in {"webots", "webots.exe", "webotsw.exe"}


def iter_webots_executable_candidates(webots_home: str) -> Iterable[str]:
    """Yield platform-specific Webots executable candidates under WEBOTS_HOME."""
    if sys.platform == "darwin":
        yield os.path.join(webots_home, "Contents", "MacOS", "webots")
    elif sys.platform == "win32":
        yield os.path.join(webots_home, "msys64", "mingw64", "bin", "webotsw.exe")
        yield os.path.join(webots_home, "msys64", "mingw64", "bin", "webots.exe")
        yield os.path.join(webots_home, "webotsw.exe")
        yield os.path.join(webots_home, "webots.exe")
    else:
        yield os.path.join(webots_home, "webots")


def resolve_webots_executable(command: list[str]) -> tuple[list[str], str | None]:
    """Resolve the executable path for the host platform.

    The Docker-side client typically asks to launch `webots`. On macOS and
    Linux, we can derive the native executable from `WEBOTS_HOME`. On Windows,
    the helper can also precompute and export `WEBOTS_EXECUTABLE`, which takes
    precedence and avoids any launcher-side patching.
    """
    requested_program = command[0]
    if not looks_like_webots_executable(requested_program):
        return command, (
            f"FAIL: '{requested_program}' is not recognized as a Webots executable."
        )

    if os.path.isabs(requested_program):
        return command, None

    webots_executable = os.environ.get("WEBOTS_EXECUTABLE")
    if webots_executable:
        command[0] = webots_executable
        return command, None

    webots_home = os.environ.get("WEBOTS_HOME")
    if not webots_home:
        return command, (
            "FAIL: WEBOTS_HOME environment variable is not defined. "
            "Please define a valid Webots installation folder."
        )

    for candidate in iter_webots_executable_candidates(webots_home):
        if os.path.isfile(candidate):
            command[0] = candidate
            return command, None

    return command, (
        f"FAIL: no supported Webots executable was found under WEBOTS_HOME={webots_home}."
    )


def validate_world_files(command: list[str]) -> str | None:
    """Validate `.wbt` arguments before starting Webots."""
    for argument in command:
        if argument.endswith(".wbt") and not os.path.isfile(argument):
            return f"FAIL: The world file '{argument}' doesn't exist."
    return None


def run_server(port: int) -> None:
    """Run the TCP server loop understood by `webots_ros2_driver`."""
    tcp_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    tcp_socket.bind((HOST, port))
    tcp_socket.listen()
    connection = None
    webots_process = None

    try:
        while True:
            print(f"Waiting for connection on port {port}...")
            connection, address = tcp_socket.accept()
            print(f"Connection from {address}")

            command = parse_command(connection.recv(BUFFER_SIZE))
            if not command:
                close_connection(connection, "FAIL: empty command received from client.")
                continue

            command, error = resolve_webots_executable(command)
            if error:
                close_connection(connection, error)
                continue

            error = validate_world_files(command)
            if error:
                close_connection(connection, error)
                continue

            try:
                webots_process = subprocess.Popen(command)
            except FileNotFoundError:
                close_connection(
                    connection,
                    f"FAIL: '{command[0]}' could not be found on the host.",
                )
                connection = None
                continue

            connection.sendall(b"ACK")
            connection.settimeout(1)
            connection_closed = False

            while webots_process.poll() is None:
                try:
                    data = connection.recv(BUFFER_SIZE)
                except socket.timeout:
                    continue

                if not data:
                    print("Connection was closed by the client.")
                    connection.close()
                    connection = None
                    webots_process.kill()
                    webots_process = None
                    connection_closed = True
                    break

            if connection_closed:
                continue

            print("Webots was executed successfully.")
            connection.sendall(b"CLOSED")
            connection.close()
            connection = None
            webots_process = None
    except KeyboardInterrupt:
        print("\nStopping Webots host server.")
    finally:
        if connection is not None:
            try:
                connection.close()
            except OSError:
                pass

        if webots_process is not None and webots_process.poll() is None:
            webots_process.kill()
            webots_process.wait()

        tcp_socket.close()


def main(argv: list[str]) -> int:
    """Parse the optional port argument and start the host server."""
    port = DEFAULT_PORT
    if len(argv) >= 2:
        try:
            port = int(argv[1])
        except ValueError:
            print(f"Invalid port value: {argv[1]}", file=sys.stderr)
            return 1

    script_path = Path(__file__).resolve()
    print("Starting repository-local Webots host server")
    print(f"  SERVER_SCRIPT={script_path}")
    print(f"  WEBOTS_HOME={os.environ.get('WEBOTS_HOME', '<unset>')}")
    print(f"  WEBOTS_EXECUTABLE={os.environ.get('WEBOTS_EXECUTABLE', '<unset>')}")
    print(
        "  WEBOTS_SHARED_HOST_DIR="
        f"{os.environ.get('WEBOTS_SHARED_HOST_DIR', '<unset>')}"
    )

    run_server(port)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
