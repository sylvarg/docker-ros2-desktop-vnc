# sylvarg/docker-ros2-desktop-vnc

This repository contains several ROS 2 desktop image variants exposed through noVNC. Detailed documentation lives alongside each variant in its own directory.

## Variant Documentation

- [`humble/`](./humble/README.md): historical version derived from the original upstream repository
- [`jazzy-webots/`](./jazzy-webots/README.md): heavily reworked ROS 2 Jazzy image with embedded Webots support on `amd64` and a host-run `external` Webots workflow for macOS and Windows
- [`rosconfr/`](./rosconfr/README.md): ROSCon France image variant built on top of `jazzy-webots`

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
