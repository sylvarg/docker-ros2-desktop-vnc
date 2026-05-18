# sylvarg/docker-ros2-desktop-vnc:jazzy-webots

This directory contains the `jazzy-webots` variant of the repository. Unlike the other [`humble/`](../humble/README.md) version of this repository (where Gazebo is used), the ROS 2 Jazzy image has been substantially reworked to support Webots (no Gazebo here), with two Webots "modes":

- `bundled`: Linux Webots is installed in the image and runs inside the container
- `external`: the container ships ROS 2 and `webots_ros2`, while Webots runs natively on the host

The main goal of this rewrite is to keep a usable image for Linux `amd64`, while also enabling a performant workflow on (Apple Silicon) macOS where Linux Webots `arm64` does not exist.

For now, the following tags are available, depending on the architecture and the way Webots is installed:

- `sylvarg/docker-ros2-desktop-vnc:jazzy-webots-embedded`: AMD64 **only** version with Webots installed inside the image
- `sylvarg/docker-ros2-desktop-vnc:jazzy-webots-external`: AMD64 **and** ARM64 version without Webots installed inside the image ; it has been tested on  macOS 26 for now and it allows to use a native Webots installation controlled and communicating with the container. AFAIK this is the only way to work with Webots on macOS (note that thanks to emulation, the `jazzy-webots-embedded` version actually works on macOS, but is very very (very) slow).

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

**So far only tested on macOS (`arm64` arch).** This might require some modifications to work on Linux.

The idea is now to install Webots natively on the host OS first, and to make the container communicate with it next.

1. Build and start the container:

```sh
docker compose -f docker-compose.macos-external.yaml up --build
```

You can also use directly the following example compose file:

```yaml
name: ros2-jazzy
services:
  ros-desktop-vnc-jazzy:
    image: sylvarg/ros2-desktop-vnc:jazzy-webots-external
    container_name: ros2_desktop_vnc_jazzy
    shm_size: "512m"
    ports:
      - "6080:6080"
    environment:
      TZ: "Europe/Paris"
      VNC_NO_PASSWORD: "true"
      WEBOTS_BACKEND: "external"
      WEBOTS_SHARED_FOLDER: "/tmp/ros2-desktop-vnc-webots-shared:/home/turtle/webots_shared"
    hostname: remotepc
    extra_hosts:
      - "remotepc:127.0.0.1"
    restart: unless-stopped          
    volumes:
      - /path/to/your/ws/src:/home/turtle/ros2_ws/src
      - type: bind
        source: /tmp/ros2-desktop-vnc-webots-shared
        target: /home/turtle/webots_shared
```

2. Start the Webots server on the host OS:

```sh
git clone https://github.com/cyberbotics/webots-server /tmp/webots-server
WEBOTS_SERVER_SCRIPT=/tmp/webots-server/local_simulation_server.py \
scripts/run_webots_host.sh
```

3. Inside the container, run your usual `ros2 launch ...` command using `webots_ros2` for launching Webots (nothing different from a standard Webots launch file here)

4. Webots should launch by itself the world specified in your launch file on the host OS

<!-- This variant builds and runs:

- the image `ros2-desktop-vnc:jazzy-webots-external-arm64`
- a `linux/arm64` container
- with native macOS Webots on the host side and ROS 2 inside the container -->

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
WEBOTS_SHARED_FOLDER=/tmp/ros2-desktop-vnc-webots-shared:/home/turtle/webots_shared
```

does not create the Docker mount by itself. The actual bind mount is defined later in [`docker-compose.macos-external.yaml`](./docker-compose.macos-external.yaml).

The script [`scripts/run_webots_host.sh`](./scripts/run_webots_host_macos.sh):

- checks `WEBOTS_HOME` (where Webots is installed on the host OS)
- checks that `WEBOTS_SERVER_SCRIPT` exists (it is provided by Cyberbotics, directy downloaded from Github)
- creates the shared directory if needed
- and finally starts the native Webots host server

## Windows

Placeholder section for a future workflow.

The intended direction is to document a dedicated Windows mode, probably around native Windows Webots and a Linux environment on the ROS 2 side. This variant is not implemented or validated in this repository yet.

## Linux

Placeholder section for future documentation.

For now, the Linux workflow documented here is mainly the `bundled` `amd64` mode. More explicit documentation for a possible Linux `external` mode can be added later if needed.

## Known Limitations

- the `embedded` image only exists on `amd64`
- `external` mode is currently documented and validated mainly for macOS
- Windows and Linux `external` documentation still needs to be completed
- the `webots_launcher` patch follows repository-specific logic and will need review if the upstream package changes significantly