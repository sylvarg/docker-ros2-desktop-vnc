# jazzy-webots-rosconfr

This directory contains the ROSCon France image variant built on top of
[`jazzy-webots/`](../jazzy-webots/README.md).

## Build

From the repository root, with Docker running, use the build script on macOS or Linux:

```sh
bash jazzy-webots-rosconfr/build.sh
```

Windows PowerShell (Linux containers):

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\jazzy-webots-rosconfr\build.ps1
```

Both scripts rebuild `ros2-desktop-vnc:jazzy-webots-external` from this checkout,
then produce `ros2-desktop-vnc:jazzy-webots-rosconfr`. They work from any current
directory. From inside this directory, use `bash build.sh` or shorten the script
path in the PowerShell command to `.\build.ps1`.

The default is `external`, matching the supplied Compose file. For container
Webots, use `bash jazzy-webots-rosconfr/build.sh embedded`, or
`-WebotsVariant embedded` with the PowerShell script. This builds the embedded
Jazzy parent and the ROSCon image for `linux/amd64`. For that image, configure
your runtime to use `WEBOTS_BACKEND=bundled` instead of the supplied external
Compose configuration. Both modes use the same ROSCon output tag; the most
recent build determines its backend.

Extra Docker arguments apply to the final ROSCon build, for example:

```sh
bash jazzy-webots-rosconfr/build.sh external --no-cache --build-arg ROSCONFR_REF=main
```

For external cross-builds, `--platform` is also forwarded to the parent build.
Backend and parent-repository arguments are set by the script to use the base
it just built. Use `docker build` directly if you need a custom parent image.

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

To include a robot SSH private key, pass it as a BuildKit secret to the script:

```sh
bash jazzy-webots-rosconfr/build.sh external \
  --secret id=rosconfr_ssh_key,src=/absolute/path/to/id_rsa_car_rosconfr \
  --build-arg ROSCONFR_REF=main
```

Windows PowerShell:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\jazzy-webots-rosconfr\build.ps1 -WebotsVariant external --secret "id=rosconfr_ssh_key,src=C:\path\to\id_rsa_car_rosconfr"
```

When the secret is provided:

- the image stores it internally as a seed file
- at container startup, the `jazzy-webots` entrypoint copies it into the runtime user's home
- the final path is `~/.ssh/id_rsa_car_rosconfr`
- a `~/.ssh/config` file is also seeded with a `Match host="10.10.10.*"` rule
- permissions are enforced as `700` on `~/.ssh` and `600` on the private key

The copy is non-destructive: if the user already has a file at that path in a
mounted or persistent home directory, the image does not overwrite it.
