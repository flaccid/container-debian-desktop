#!/bin/bash
# Ensure the X server's built-in screen saver timeout matches our
# desired idle timeout (3600s = 1 hour).
#
# xfce4-screensaver reads /saver/idle-activation/delay from xfconf
# (set to 60 minutes) and passes it to XSetScreenSaver as seconds
# (3600).  This script waits for the daemon to initialise, then
# re-applies the timeout as a safety measure against race conditions.

# Wait for xfce4-screensaver to actually be running (it starts after
# the XFCE session is up).
for i in $(seq 1 10); do
    if xfce4-screensaver-command -q >/dev/null 2>&1; then
        break
    fi
    sleep 1
done

# The preferences GUI reads /saver/idle-activation/delay from xfconf.
# GSettings (org.gnome.desktop.session idle-delay) is also set for
# any component that still reads from it.
gsettings set org.gnome.desktop.session idle-delay 3600

# Re-apply the X server timeout repeatedly as a safety net against
# any race where the daemon's XSetScreenSaver call races with ours.
for i in $(seq 1 10); do
    xset s 3600 3600
    sleep 1
done
