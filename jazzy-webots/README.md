# sylvarg/docker-ros2-desktop-vnc:jazzy-webots

This directory contains the `jazzy-webots` variant of the repository. Unlike the other [`humble/`](../humble/README.md) version of this repository (where Gazebo is used), the ROS 2 Jazzy image has been substantially reworked to support Webots (no Gazebo here), with two Webots "modes":

- `bundled`: Linux Webots is installed in the image and runs inside the container
- `external`: the container ships ROS 2 and `webots_ros2`, while Webots runs natively on the host

The main goal of this rewrite is to keep a usable image for Linux `amd64`, while also enabling performant host-run Webots workflows on macOS and Windows when keeping the simulator outside the container is preferable.

For now, the following tags are available, depending on the architecture and the way Webots is installed:

- `sylvarg/docker-ros2-desktop-vnc:jazzy-webots-embedded`: AMD64 **only** version with Webots installed inside the image
- `sylvarg/docker-ros2-desktop-vnc:jazzy-webots-external`: AMD64 **and** ARM64 version without Webots installed inside the image ; it has been tested on macOS 26 for now and it allows a native host Webots installation to be controlled and to communicate with the container. The same container-side workflow is now documented for Windows with a dedicated PowerShell helper, although it still needs validation on a real Windows setup. AFAIK this remains the only practical way to work with Webots on macOS (note that thanks to emulation, the `jazzy-webots-embedded` version actually works on macOS, but is very very (very) slow).

## Quick Start

### Embedded (`amd64` only) variant

If you want to build this image, from this directory:

```sh
docker compose -f docker-compose-embedded.yaml up --build
```

Then open `http://127.0.0.1:6080`.

This variant builds and runs:

- the image `ros2-desktop-vnc:jazzy-webots-embedded`
- a `linux/amd64` container
- with Webots installed inside the image

You can also directly use the following example compose file:

```yaml
name: ros2-jazzy
services:
  ros-desktop-vnc-jazzy:
    image: sylvarg/ros2-desktop-vnc:jazzy-webots-embedded
    container_name: ros2_desktop_vnc_jazzy
    platform: linux/amd64
    shm_size: "512m"
    ports:
      - "6080:6080"
    environment:
      TZ: "Europe/Paris"
      VNC_NO_PASSWORD: "true"
      WEBOTS_BACKEND: "bundled"
    hostname: remotepc
    extra_hosts:
      - "remotepc:127.0.0.1"
    restart: unless-stopped          
    volumes:
      - /path/to/your/ws/src:/home/turtle/ros2_ws/src
```

### External (`amd64` and `arm64`) variant

The `external` variant keeps ROS 2 and `webots_ros2` inside the Linux container while Webots itself runs natively on the host OS. The container-side setup is the same on macOS and Windows; only the host helper used to start `local_simulation_server.py` changes.

Host prerequisites:

- Docker Desktop configured for Linux containers
- a native Webots installation on the host OS
- Python 3 on the host for macOS / Linux; on Windows the helper can offer to install the official Python Install Manager interactively when Python is missing
- outbound HTTPS access so the Windows helper can download `local_simulation_server.py` automatically on first start, or a local copy of that file passed explicitly through `-WebotsServerScript`

Docker will normally build the container for the host architecture automatically, which is the recommended path for this `external` mode.

1. Build and start the container:

```sh
docker compose -f docker-compose-external.yaml up --build
```

You can also use directly the following example compose file:

```yaml
name: ros2-jazzy
services:
  ros-desktop-vnc-jazzy:
    image: sylvarg/ros2-desktop-vnc:jazzy-webots-external
    container_name: ros2_desktop_vnc_jazzy_external
    shm_size: "512m"
    ports:
      - "6080:6080"
    environment:
      TZ: "Europe/Paris"
      VNC_NO_PASSWORD: "true"
      WEBOTS_BACKEND: "external"
      WEBOTS_SHARED_FOLDER: "${WEBOTS_SHARED_HOST_DIR:-/tmp/ros2-desktop-vnc-webots-shared}:${CONTAINER_WEBOTS_SHARED_DIR:-/home/turtle/webots_shared}"
    hostname: remotepc
    extra_hosts:
      - "remotepc:127.0.0.1"
    restart: unless-stopped          
    volumes:
      - /path/to/your/ws/src:/home/turtle/ros2_ws/src
      - type: bind
        source: ${WEBOTS_SHARED_HOST_DIR:-/tmp/ros2-desktop-vnc-webots-shared}
        target: ${CONTAINER_WEBOTS_SHARED_DIR:-/home/turtle/webots_shared}
```

2. Start the Webots server on the host OS:

macOS / Linux:

```sh
git clone https://github.com/cyberbotics/webots-server /tmp/webots-server
WEBOTS_SERVER_SCRIPT=/tmp/webots-server/local_simulation_server.py \
scripts/run_webots_host.sh
```

Windows (PowerShell):

```powershell
$env:WEBOTS_SHARED_HOST_DIR = Join-Path $env:TEMP "ros2-desktop-vnc-webots-shared"
.\scripts\run_webots_host.cmd
```

If Python is not already available on Windows, the script will ask whether it
should install the official Python Install Manager first. When `winget` is
available, the installation is launched directly from the terminal; otherwise
the official download page is opened in the browser and the script waits for
confirmation before continuing.

3. Inside the container, run your usual `ros2 launch ...` command using `webots_ros2` for launching Webots (nothing different from a standard Webots launch file here)

4. Webots should launch by itself the world specified in your launch file on the host OS

### Make the container communicate with an external host

The image also includes [`zenoh-bridge-ros2dds`](https://github.com/eclipse-zenoh/zenoh-plugin-ros2dds). It allows the container to communicate with an external host (e.g. a robot), which is not always possible even in host mode (in particular with a Windows or macos host). Note that [`zenoh-bridge-ros2dds`](https://github.com/eclipse-zenoh/zenoh-plugin-ros2dds) must also be installed on the robot.

Consider the robot has an IP address `192.168.0.10`. On the robot, launch `zenoh-bridge-ros2dds`. Then you can connect the docker container to the robot trough the zenoh bridge by typing in a terminal inside the container: `zenoh-bridge-ros2dds -e tcp/192.168.0.10:7447`. Then, both hosts (the robot and the container) will communicate together through the bridge. In Jazzy, the default shell configuration sets `ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST` so DDS discovery stays local to each host and inter-host communication goes through `zenoh-bridge-ros2dds`. This can be changed in the `.bashrc` file if needed inside the container.

## External variant: detailed Workflow

The external version of the image relies on two components: the Linux container, running ROS 2, `webots_ros2`, launch files, controllers, etc. and 
the host OS running Webots natively via `local_simulation_server.py`. Communication between the two happens through TCP between `webots_ros2_driver` and the native Webots host server, helped by a shared host/container directory described by `WEBOTS_SHARED_FOLDER`

By default, `WEBOTS_SHARED_FOLDER` is set to:

- host path: `/tmp/ros2-desktop-vnc-webots-shared`
- container path: `/home/turtle/webots_shared`

Note that the variable `WEBOTS_SHARED_FOLDER` in the compose file:

```text
WEBOTS_SHARED_FOLDER=${WEBOTS_SHARED_HOST_DIR:-/tmp/ros2-desktop-vnc-webots-shared}:${CONTAINER_WEBOTS_SHARED_DIR:-/home/turtle/webots_shared}
```

does not create the Docker mount by itself. The actual bind mount is defined later in [`docker-compose-external.yaml`](./docker-compose-external.yaml).

The helper scripts [`scripts/run_webots_host.sh`](./scripts/run_webots_host.sh), [`scripts/run_webots_host.ps1`](./scripts/run_webots_host.ps1), and [`scripts/run_webots_host.cmd`](./scripts/run_webots_host.cmd):

- checks `WEBOTS_HOME` (where Webots is installed on the host OS)
- resolves `WEBOTS_SERVER_SCRIPT`, downloading `local_simulation_server.py` automatically on Windows when it is not already present locally
- creates the shared directory if needed
- and finally starts the native Webots host server

## Windows

The Windows workflow mirrors the macOS one:

- native Windows Webots runs on the host
- the Linux Docker container runs ROS 2 and `webots_ros2`
- `local_simulation_server.py` bridges the two
- the shared folder is still described with `WEBOTS_SHARED_FOLDER`, but the image now patches `webots_ros2_driver` so Windows drive-letter paths such as `C:\...` remain parseable
- if Python is missing, `run_webots_host.cmd` can propose installation of the official Python Install Manager before launching the host server

Recommended prerequisites on Windows:

- Docker Desktop with Linux containers enabled
- Webots installed in its default location (`C:\Program Files\Webots`) or `WEBOTS_HOME` set explicitly
- no preinstalled Python is strictly required if you accept the helper's installation prompt, but outbound internet access is needed for that path
- no special PowerShell execution-policy setup is needed when starting through `run_webots_host.cmd`
- a host directory shared with Docker Desktop for the Webots exchange folder

## Linux

Placeholder section for future documentation.

For now, the Linux workflow documented here is mainly the `bundled` `amd64` mode. More explicit documentation for a possible Linux `external` mode can be added later if needed.

## Known Limitations

- the `embedded` image only exists on `amd64`
- `external` mode is currently validated mainly on macOS; the Windows helper and compose flow still need end-to-end validation on a real Windows machine
- Linux `external` documentation still needs to be completed
- the `webots_launcher` patch follows repository-specific logic and will need review if the upstream package changes significantly
