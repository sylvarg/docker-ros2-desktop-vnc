# sylvarg/docker-ros2-desktop-vnc:rosconfr

This directory contains the `rosconfr` image variant built on top of
[`jazzy-webots/`](../jazzy-webots/README.md).

## Build

Example for the external Webots backend:

```sh
docker buildx build \
  --build-arg WEBOTS_BACKEND=external \
  -t ros2-desktop-vnc:rosconfr-external \
  ./rosconfr
```

## Optional SSH private key

If you want the image to ship a robot SSH private key, pass it as a BuildKit
secret when building the image:

```sh
docker buildx build \
  --build-arg WEBOTS_BACKEND=external \
  --secret id=rosconfr_ssh_key,src=/absolute/path/to/id_rsa_car_rosconfr \
  -t ros2-desktop-vnc:rosconfr-external \
  ./rosconfr
```

When the secret is provided:

- the image stores it internally as a seed file
- at container startup, the `jazzy-webots` entrypoint copies it into the runtime user's home
- the final path is `~/.ssh/id_rsa_car_rosconfr`
- a `~/.ssh/config` file is also seeded with a `Match host="10.10.10.*"` rule
- permissions are enforced as `700` on `~/.ssh` and `600` on the private key

The copy is non-destructive: if the user already has a file at that path in a
mounted or persistent home directory, the image does not overwrite it.
