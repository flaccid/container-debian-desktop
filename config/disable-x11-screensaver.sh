#!/bin/bash
# Disable the X server's built-in screen saver by setting its timeout
# to match xfce4-screensaver's xfconf value (3600s = 1 hour).
#
# xfce4-screensaver sets the X server timeout to 300 on startup, which
# interferes with our desired idle timeout.  This script runs from XFCE
# autostart after the session (including xfce4-screensaver) has fully
# initialised and sets the X server timeout to the correct value.

sleep 5

# The xfce4-screensaver preferences GUI reads the idle timeout from
# GSettings (org.gnome.desktop.session idle-delay), not from xfconf.
# Set it here so the GUI shows the correct value.
gsettings set org.gnome.desktop.session idle-delay 3600

# xfce4-screensaver resets the X server's built-in screen saver timeout
# to 300 whenever GSettings changes.  Override it to match our desired
# idle timeout of 1 hour.
xset s 3600 3600
