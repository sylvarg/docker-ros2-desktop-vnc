#!/bin/sh
unset DBUS_SESSION_BUS_ADDRESS
# VNC sessions are expected to stay visible and interactive, so disable
# the X11 screen saver and display power management entirely.
xset s off
xset s noblank
xset -dpms
# Start the desktop session from the user's home so terminals inherit a sane
# default working directory instead of the container's image-level WORKDIR.
cd "$HOME"
mate-session
