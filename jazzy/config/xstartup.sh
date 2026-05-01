#!/bin/sh
unset DBUS_SESSION_BUS_ADDRESS
# VNC sessions are expected to stay visible and interactive, so disable
# the X11 screen saver and display power management entirely.
xset s off
xset s noblank
xset -dpms
mate-session
