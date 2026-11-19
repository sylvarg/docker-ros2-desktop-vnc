# Native Webots host server

The external variants run ROS 2 in Docker and Webots on the host. The shared
Python server listens on TCP port 2000 by default. It receives requests from
`webots_ros2_driver` and opens the staged world in native Webots. The server
uses the Python standard library and follows the
[Cyberbotics Webots server protocol](https://github.com/cyberbotics/webots-server).

Install Webots on the host. On macOS or Linux, make sure `python3` is on
`PATH`. On Windows, the launcher can offer to install the official Python
Install Manager if it cannot find a working Python 3 interpreter.

## Jazzy external with defaults

Run Compose as described in the [Jazzy guide](../jazzy-webots/README.md).
From the repository root, run the host launcher without arguments.

macOS and Linux:

```sh
sh local_webots_server/run_webots_host.sh
```

Windows PowerShell:

```powershell
.\local_webots_server\run_webots_host.cmd
```

The launchers look for Webots in the standard installation locations. Set
`WEBOTS_HOME` if Webots is installed elsewhere. The default exchange
directory is `/tmp/ros2-desktop-vnc-webots-shared` on macOS and Linux and
`ros2-desktop-vnc-webots-shared` under the Windows temporary directory.
Set `WEBOTS_SHARED_HOST_DIR` to the same value in the environment of Compose
and the launcher when using a custom directory or running Compose on Windows.

## TB3, Ned2 and ROSCon with an env file

Use the same profile from the repository root for Compose and the host launcher.
Choose [`env.macos`](../env.macos), [`env.linux`](../env.linux) or
[`env.windows`](../env.windows) and adjust the host paths. Use
[`env.example`](../env.example) as a template for a custom profile.
Leave `WEBOTS_HOME` empty to use the standard Webots installation location.

macOS, from the repository root:

```sh
sh local_webots_server/run_webots_host.sh --env-file env.macos
```

Use `env.linux` on Linux. On Windows PowerShell:

```powershell
.\local_webots_server\run_webots_host.cmd --env-file env.windows
```

On Windows, you can also call `run_webots_host.ps1` with `-EnvFile`.
For either launcher, pass a port number at the end to change the listening port.
Configure the container client to use the same port.
