#!/bin/bash
# Disable the X server's built-in screen saver by setting its timeout
# to match xfce4-screensaver's xfconf value (3600s = 1 hour).
#
# xfce4-screensaver sets the X server timeout to 300 on startup, which
# interferes with our desired idle timeout.  This script runs from XFCE
# autostart after the session (including xfce4-screensaver) has fully
# initialised and sets the X server timeout to the correct value.

sleep 3
xset s 3600 3600
