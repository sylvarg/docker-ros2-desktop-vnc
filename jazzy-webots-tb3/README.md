# sylvarg/docker-ros2-desktop-vnc:jazzy-webots-tb3

TurtleBot3 desktop for robotics labs based on the current [`jazzy-webots`](../jazzy-webots/README.md)
sources. Webots always runs natively on the host: there is no backend to select
and no Linux Webots installation in this image. Both `amd64` and `arm64` use
the same workflow, building for the host architecture by default.

The image keeps the Jazzy desktop, ROS tools, Webots launcher patches, Zenoh
bridge, shell defaults and entrypoint. The wallpaper for the labs is stored as
`background/wallpaper_tb3.png`. It includes the ROBOTIS TurtleBot3 packages below
and does not include the ROSCon ROS workspace.

## TurtleBot3 packages

Following the [ROBOTIS Jazzy PC setup](https://docs.robotis.com/docs/systems/turtlebot3/quick_start_guide/pc_setup/),
the image clones and builds the `jazzy` branches of:

- `ROBOTIS-GIT/DynamixelSDK`
- `ROBOTIS-GIT/turtlebot3_msgs`
- `ROBOTIS-GIT/turtlebot3`

Sources are kept in `/opt/turtlebot3_ws/src`, with the prebuilt installation in
`/opt/turtlebot3_ws/install`. The workspace is available to all desktop users and
is sourced automatically through `/etc/ros-desktop-vnc/bashrc.d/20-turtlebot3.sh`.
The loading order is ROS Jazzy, TurtleBot3, then `~/ros2_ws`, so your own packages
can override the preinstalled ones.

Unlike an interactive development build, this image uses a self-contained merged
installation without symlinks, allowing build artifacts and logs to be removed.
The inherited `symlink-install` default is preserved for user workspaces.
`python3-colcon-common-extensions` is already installed in the parent image.

The TB3 variant also installs `ros-jazzy-joint-state-publisher-gui` for interactive
URDF joint controls and constrains pip NumPy to `<2`. The latter prevents the
parent's pip NumPy 2 from shadowing Ubuntu's NumPy 1.x and breaking the system
OpenCV / ROS `cv_bridge` extensions. Both adjustments are specific to this variant;
the shared Jazzy base is unchanged.

Only build dependencies of the source repositories are resolved with `rosdep`. Gazebo, Cartographer and
Navigation2 are not installed. The TurtleBot3 repository contains Cartographer
and Navigation2 launch configurations, but these do not supply the corresponding
runtime stacks. Hardware drivers needed by bringup on the robot itself remain
part of its SBC setup.

## Build from the current checkout

Run from this directory, with Docker running:

```sh
bash build.sh
```

Windows PowerShell:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\build.ps1
```

The script first builds `ros2-desktop-vnc:jazzy-webots-tb3-base` from the sibling
`jazzy-webots/` directory with external Webots, then builds and loads
`ros2-desktop-vnc:jazzy-webots-tb3`. It uses the current checkout rather than a
potentially older published parent. Keep both directories in the repository.
Run this script again after changing the parent image sources.

The Dockerfile can also be built directly once the local parent exists. Its
`BASE_IMAGE` build argument can select an already-built compatible Jazzy external
image when needed.

## Optional SSH key for the labs

The parent entrypoint already handles SSH initialization. To supply a key for lab robots,
pass a BuildKit secret to the build script:

```sh
labs_key="$HOME/.ssh/id_ed25519_tb3_tp"
labs_fingerprint="$(ssh-keygen -lf "$labs_key.pub" | awk '{print $2}')"
bash build.sh \
  --secret "id=tb3_ssh_key,src=$labs_key" \
  --build-arg "TB3_SSH_KEY_FINGERPRINT=$labs_fingerprint"
```

Windows PowerShell:

```powershell
$LabsKey = Join-Path $HOME ".ssh\id_ed25519_tb3_tp"
$LabsFingerprint = ((ssh-keygen -lf "$LabsKey.pub") -split '\s+')[1]
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\build.ps1 --secret "id=tb3_ssh_key,src=$LabsKey" --build-arg "TB3_SSH_KEY_FINGERPRINT=$LabsFingerprint"
```

The key is optional. When supplied, it is baked into the TB3 image as a seed and
copied to `~/.ssh/id_rsa_tb3` at startup, along with its derived public key at
`~/.ssh/id_rsa_tb3.pub`. This filename also accepts an Ed25519 key. A default SSH config selects it with
`Host *`, without assuming a robot address or disabling host-key verification.
The entrypoint enforces `700` on `~/.ssh` and `600` on the private key and config.
Existing key and config files are preserved; if an existing config does not
select the lab key, use `ssh -i ~/.ssh/id_rsa_tb3 user@robot-address` explicitly.
Git tracks the [lab public key](./ssh/id_ed25519_tb3_tp.pub) and ignores the
private key in `ssh/`. The Docker build context excludes the `ssh/` directory.

Compose runs the image produced by the build script. To rebuild it with the
key, use `build.sh` / `build.ps1` with the secret and its fingerprint again.
The public fingerprint invalidates the SSH build layer when the key changes;
BuildKit secret contents alone do not invalidate cached layers.

## Configure and start the desktop

Use the `env.macos`, `env.linux` or `env.windows` profile at the repository root.
Set `ROS2_WS_SRC_HOST_DIR` and `WEBOTS_SHARED_HOST_DIR` to your host paths and
create both directories before starting.
`WEBOTS_HOME` may stay empty when Webots is installed in its usual host location.

From the repository root on macOS, create the host directories and start Compose.

```sh
mkdir -p /Users/your-user/ros2_ws/src /tmp/ros2-desktop-vnc-webots-shared
docker compose --env-file env.macos -f jazzy-webots-tb3/docker-compose.yaml up -d
```

On Linux, use `--env-file env.linux`; on Windows, use `--env-file env.windows`.
Open <http://localhost:6080> for the desktop. `WEBOTS_BACKEND=external` is already
defined in the image, and the Compose file supplies the shared folder mapping.
The variable alone does not create the Docker bind mount.

Compose mounts `~/ros2_ws/src` and the Webots exchange directory
`~/.webots_shared` from the host.
User workspace `build/`, `install/`, `log/` and other home files are stored in the
container and are lost if it is removed. Run `colcon build` in `~/ros2_ws` as needed;
the resulting workspace is sourced automatically in new terminals.

## Start native Webots on the host

Install native Webots and Python 3 on the host. From the repository root,
run the [shared host launcher](../local_webots_server/README.md)
in a separate host terminal. Use the same env file as Compose.

```sh
sh local_webots_server/run_webots_host.sh --env-file env.macos
```

Windows:

```powershell
.\local_webots_server\run_webots_host.cmd --env-file env.windows
```

On Linux, use `env.linux`. The server listens on TCP port `2000` by default.
The Windows helper can offer to install Python when it is missing.
Launch your simulation from the container with its normal `ros2 launch ...`
command using `webots_ros2`: the host server opens the requested world in native
Webots. This variant adds the standard ROBOTIS packages, but no custom lab world
or launch file.
Windows and Linux external workflows still need end-to-end validation.

## ROS defaults

Inherited defaults are `TURTLEBOT3_MODEL=burger`, `ROS_DOMAIN_ID=30` and
`ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST`. The TB3 variant adds this editable line
at the end of `/home/turtle/.bashrc` (and the root user's `.bashrc`):

```bash
export TB3_IP=192.168.0.248
```

Students can use `eb` to edit that file and `sb` to reload it. This explicit
assignment takes precedence over the shared default, including after changing
the address in an already-open shell. It is specific to the TB3 variant.
If upgrading a saved `.bashrc`, rename its previous `ROBOT_IP` assignment to
`TB3_IP`. The `zenoh` alias connects to `tcp/$TB3_IP:7447`; it does not start automatically.
See the [Jazzy documentation](../jazzy-webots/README.md) for the robot-side bridge
and the shared-folder architecture.

## Host and desktop clipboard

To paste text copied on the host directly into the VNC desktop, click the target
application and use the host's native paste shortcut:

- macOS: `Cmd+V`
- Windows / Linux: `Ctrl+V` (or `Ctrl+Shift+V`)

The TB3 image patches the noVNC clipboard fork to receive the browser's native
paste event, transfer the text to VNC and paste it into the focused Linux
application. This also works when the browser refuses automatic clipboard reads.
It supports plain text, including Unicode and multiple lines.

Automatic clipboard synchronization is also retried when returning to the
browser window or clicking an already focused VNC desktop, when browser
permissions allow it. Copying from the desktop back to the host is preserved.

After a client update, reload the noVNC page to load the new JavaScript. Reloading
the page reconnects to the existing desktop; desktop applications keep running.
