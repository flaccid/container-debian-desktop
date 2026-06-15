#!/bin/bash
# If we are running as root, re-run this script as the admin user
if [ "$(id -u)" = "0" ]; then
    # Populate the home directory if it's the first run
    if [ ! -f "/home/admin/.vnc/xstartup" ]; then
        echo "First run: Populating /home/admin with default configuration..."
        cp -r /etc/skel/admin/. /home/admin/
        chown -R admin:admin /home/admin
    fi
    # Drop privileges and execute the main container command
    exec gosu admin "$@"
else
    # If already running as admin, just execute the command
    exec "$@"
fi
