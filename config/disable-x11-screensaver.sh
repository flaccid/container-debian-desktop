#!/bin/bash
# Disable the X server's built-in screen saver by setting its timeout
# to match xfce4-screensaver's xfconf value (3600s = 1 hour).
#
# xfce4-screensaver sets the X server timeout to 300 on startup, which
# interferes with our desired idle timeout.  This script runs from XFCE
# autostart after the session (including xfce4-screensaver) has fully
# initialised and sets the X server timeout to the correct value.

# Wait for xfce4-screensaver to actually be running (it starts after
# the XFCE session is up and resets xset to 300 on first init).
for i in $(seq 1 10); do
    if xfce4-screensaver-command -q >/dev/null 2>&1; then
        break
    fi
    sleep 1
done

# The xfce4-screensaver preferences GUI reads the idle timeout from
# GSettings (org.gnome.desktop.session idle-delay), not from xfconf.
# Set it here so the GUI shows the correct value.
gsettings set org.gnome.desktop.session idle-delay 3600

# xfce4-screensaver resets the X server's built-in screen saver timeout
# to 300 whenever GSettings changes.  Override it to match our desired
# idle timeout of 1 hour.  Run twice to catch any re-apply triggered
# by the GSettings write above.
xset s 3600 3600
sleep 1
xset s 3600 3600
