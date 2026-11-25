# sylvarg/docker-ros2-desktop-vnc

This repository contains several ROS 2 desktop image variants exposed through noVNC. Detailed documentation lives alongside each variant in its own directory.

The external Webots variants share the [native Webots host launcher](./local_webots_server/README.md) and the `env.*` profiles in the repository root.

## Variant Documentation

- [`humble/`](./humble/README.md): historical version derived from the original upstream repository
- [`jazzy-webots/`](./jazzy-webots/README.md): heavily reworked ROS 2 Jazzy image with embedded Webots support on `amd64` and a host-run `external` Webots workflow for macOS and Windows
- [`jazzy-webots-tb3/`](./jazzy-webots-tb3/README.md): TurtleBot3 image for robotics labs built from the current Jazzy sources, with host-run Webots only, a dedicated wallpaper and an optional SSH key for lab robots
- [`jazzy-webots-tb3-ned2/`](./jazzy-webots-tb3-ned2/README.md): extends the TurtleBot3 image with MoveIt 2 and the Niryo driver for real and simulated Ned2 arms
- [`jazzy-webots-rosconfr/`](./jazzy-webots-rosconfr/README.md): ROSCon France image variant built on top of `jazzy-webots`

## Build images

With Docker running in Linux-container mode, run the appropriate script from
the repository root. The scripts create local images; start containers separately
with each variant's documented Compose command.

| Variant | macOS / Linux command | Local image tag |
| --- | --- | --- |
| Humble | `bash humble/build.sh` | `ros2-desktop-vnc:humble` |
| Jazzy, host Webots (default) | `bash jazzy-webots/build.sh` | `ros2-desktop-vnc:jazzy-webots-external` |
| Jazzy, container Webots | `bash jazzy-webots/build.sh embedded` | `ros2-desktop-vnc:jazzy-webots-embedded` |
| TurtleBot3 | `bash jazzy-webots-tb3/build.sh` | `ros2-desktop-vnc:jazzy-webots-tb3` |
| TurtleBot3 + Ned2 | `bash jazzy-webots-tb3-ned2/build.sh` | `ros2-desktop-vnc:jazzy-webots-tb3-ned2` |
| ROSCon France | `bash jazzy-webots-rosconfr/build.sh` | `ros2-desktop-vnc:jazzy-webots-rosconfr` |

Every variant also provides `build.ps1`. For example, on Windows PowerShell:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\jazzy-webots\build.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\jazzy-webots-rosconfr\build.ps1
```

Jazzy and ROSCon default to `external`; select `embedded` in Bash or
`-WebotsVariant embedded` in PowerShell for container Webots. Embedded builds
always target `linux/amd64`. ROSCon rebuilds its matching Jazzy parent from this
checkout before building the derived image. TB3 and Ned2 keep their documented
parent-image workflows and optional SSH-key support.

The external image is also the shared parent of the TB3 and ROSCon variants:

```text
ros2-desktop-vnc:jazzy-webots-external
├── ros2-desktop-vnc:jazzy-webots-tb3
│   └── ros2-desktop-vnc:jazzy-webots-tb3-ned2
└── ros2-desktop-vnc:jazzy-webots-rosconfr
```

The scripts resolve their build context relative to their own location, so they
also work from another current directory. Additional Docker build arguments can
be appended, for example `bash jazzy-webots/build.sh external --no-cache`.
See the individual READMEs for variant-specific options and SSH secrets.

## Repository Contents

This repository has been inspired by [Tiryoh/docker-ros2-desktop-vnc](https://github.com/Tiryoh/docker-ros2-desktop-vnc) which has served as a basis for the `humble` version of the image. Since then, I have also reworked on image variants adapted to different ROS 2 versions (Jazzy for now), still with a noVNC integration to access the graphical desktop from a browser. **This version will be used during the Hackathon taking place in Paris for the [ROSCon France 2026](https://roscon.ros.org/fr/2026/)**.

The Jazzy version specifically provides Webots-specific adjustments to allow the use of an "external" (i.e. outside the running Docker container) Webots installation, especially for macOS since no Linux/arm64 version of Webots exists. The same architecture is now also documented for Windows with a dedicated PowerShell host helper, although it still needs validation on a real Windows setup. I have not tested the same approach for Linux for now, but it might work directly.

## Current Status

Recent work has mainly focused on the Jazzy rewrite, now with Webots (no gazebo):

- migration to ROS 2 Jazzy on Ubuntu Noble
- split between `bundled` and `external` Webots backends
- explicit support for host-run Webots workflows, with documented helpers for macOS and Windows
- a patched `webots_ros2` launcher to transfer worlds, `PROTO` files, assets, and controllers correctly

## Related Projects

- https://github.com/atinfinity/nvidia-egl-desktop-ros2
- https://github.com/fcwu/docker-ubuntu-vnc-desktop
- https://github.com/AtsushiSaito/docker-ubuntu-sweb

## License

This repository is released under the Apache 2.0 license. See [LICENSE](./LICENSE).

## Acknowledgements

- [Tiryoh/docker-ros2-desktop-vnc](https://github.com/Tiryoh/docker-ros2-desktop-vnc)
- [AtsushiSaito/docker-ubuntu-sweb](https://github.com/AtsushiSaito/docker-ubuntu-sweb)
- [fcwu/docker-ubuntu-vnc-desktop](https://github.com/fcwu/docker-ubuntu-vnc-desktop)
