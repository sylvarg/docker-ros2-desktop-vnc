# Local Webots Server

This directory contains a repository-local replacement for the previous host
server workflow used by the `jazzy-webots` external mode.

The new layout is intentionally simple:

- [`local_simulation_server.py`](./local_simulation_server.py): one Python
  server implementation shared by Linux, macOS, and Windows
- [`run_webots_host.sh`](./run_webots_host.sh): Unix launcher for Linux and
  macOS
- [`run_webots_host.ps1`](./run_webots_host.ps1): Windows launcher
- [`run_webots_host.cmd`](./run_webots_host.cmd): convenience wrapper that
  starts the PowerShell launcher with an execution-policy bypass for the
  current process only

## Why this directory exists

In the `external` mode of `jazzy-webots`, ROS 2 and `webots_ros2` run inside a
Linux Docker container, while Webots itself runs natively on the host OS. This
means the container cannot simply spawn the host Webots process directly: it
needs a small TCP server running on the host, whose only job is to receive a
launch request from the container and start Webots locally with the requested
world file.

Cyberbotics already provides such a helper upstream in the
`webots-server` repository:

- upstream repository: [cyberbotics/webots-server](https://github.com/cyberbotics/webots-server)
- upstream script: [local_simulation_server.py](https://github.com/cyberbotics/webots-server/blob/main/local_simulation_server.py)

Historically, the macOS / Linux flow could rely directly on that upstream
script, because its executable-resolution logic already matches Unix-like
installations reasonably well.

Windows is different. In our workflow, the host helper needs to resolve the
native Windows Webots executable correctly, typically `webotsw.exe` under the
Webots installation directory. The upstream script is not designed as a
turnkey multi-platform helper for this repository's Docker workflow, so we propose our own simulation server highly inspired by the original upstream script. Consequently:

1. the Python host server is now versioned in this repository
2. Linux, macOS, and Windows all use the same server implementation
3. the shell and PowerShell launchers only perform lightweight host bootstrap

## How it works

The Python server implements the same basic role as the Cyberbotics helper:

1. listen on TCP port `2000` by default
2. wait for a command sent by the Docker-side Webots client
3. resolve the native Webots executable on the current host OS
4. launch Webots on the host
5. keep the TCP connection open until Webots exits or the client disconnects

The wrappers around it are deliberately thin:

- the Unix launcher chooses a default `WEBOTS_HOME`, checks `python3`, creates
  the shared host directory, exports the environment, and starts the Python
  server
- the Windows launcher finds `webotsw.exe`, checks whether Python is available,
  can offer installation of the official Python Install Manager when Python is
  missing, creates the shared host directory, exports the environment, and
  starts the same Python server

## Prerequisites

Common prerequisites:

- Docker Desktop configured for Linux containers
- a native Webots installation on the host OS
- the `jazzy-webots` external Docker workflow already configured on the
  container side

Platform-specific prerequisites:

- Linux / macOS: `python3` available in `PATH`
- Windows: either Python already available, or acceptance of the launcher's
  prompt to install the official Python Install Manager

## Usage

From the `jazzy-webots` directory, first start the external container:

```sh
docker compose -f docker-compose-external.yaml up --build
```

Then start the host-side Webots server.

### macOS / Linux

```sh
bash local_webots_server/run_webots_host.sh
```

Optional environment overrides:

```sh
WEBOTS_HOME=/path/to/Webots.app \
WEBOTS_SHARED_HOST_DIR=/tmp/ros2-desktop-vnc-webots-shared \
bash local_webots_server/run_webots_host.sh
```

You can also pass an alternate TCP port:

```sh
bash local_webots_server/run_webots_host.sh 2001
```

### Windows

PowerShell:

```powershell
$env:WEBOTS_SHARED_HOST_DIR = Join-Path $env:TEMP "ros2-desktop-vnc-webots-shared"
.\local_webots_server\run_webots_host.ps1
```

Or, if you prefer the execution-policy-safe wrapper:

```powershell
.\local_webots_server\run_webots_host.cmd
```

You can also override the Webots installation path explicitly:

```powershell
.\local_webots_server\run_webots_host.ps1 -WebotsHome "D:\Apps\Webots"
```

And you can pass an alternate TCP port after the named arguments:

```powershell
.\local_webots_server\run_webots_host.ps1 -WebotsHome "C:\Program Files\Webots" 2001
```

## Notes

- The server uses only Python's standard library.
- The existing helpers under [`../scripts`](../scripts) are left untouched.
- This directory is the recommended path for future external-host workflows
  because it avoids runtime patching of upstream files.
