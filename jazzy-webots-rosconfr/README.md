# jazzy-webots-rosconfr

This directory contains the ROSCon France image variant built on top of
[`jazzy-webots/`](../jazzy-webots/README.md).

## Build

From the repository root, build the external base if it is unavailable locally.

```sh
docker build --build-arg WEBOTS_BACKEND=external \
  -t ros2-desktop-vnc:jazzy-webots-external ./jazzy-webots
```

Build the ROSCon image from that base.

```sh
docker build \
  --build-arg BASE_IMAGE_REPOSITORY=ros2-desktop-vnc \
  --build-arg WEBOTS_BACKEND=external \
  -t ros2-desktop-vnc:jazzy-webots-rosconfr \
  ./jazzy-webots-rosconfr
```

## Start native Webots on the host

From the repository root, start Compose with your root `env.*` profile, then
run the [shared host launcher](../local_webots_server/README.md) with the same
profile. Set your actual Windows user and workspace paths in `env.windows`
before starting.

```sh
docker compose --env-file env.macos -f jazzy-webots-rosconfr/docker-compose.yaml up -d
sh local_webots_server/run_webots_host.sh --env-file env.macos
```

Use `env.linux` on Linux. On Windows PowerShell:

```powershell
.\local_webots_server\run_webots_host.cmd --env-file env.windows
```

## Optional SSH private key

If you want the image to ship a robot SSH private key, pass it as a BuildKit
secret when building the image:

```sh
docker build \
  --build-arg BASE_IMAGE_REPOSITORY=ros2-desktop-vnc \
  --build-arg WEBOTS_BACKEND=external \
  --secret id=rosconfr_ssh_key,src=/absolute/path/to/id_rsa_car_rosconfr \
  -t ros2-desktop-vnc:jazzy-webots-rosconfr \
  ./jazzy-webots-rosconfr
```

When the secret is provided:

- the image stores it internally as a seed file
- at container startup, the `jazzy-webots` entrypoint copies it into the runtime user's home
- the final path is `~/.ssh/id_rsa_car_rosconfr`
- a `~/.ssh/config` file is also seeded with a `Match host="10.10.10.*"` rule
- permissions are enforced as `700` on `~/.ssh` and `600` on the private key

The copy is non-destructive: if the user already has a file at that path in a
mounted or persistent home directory, the image does not overwrite it.
