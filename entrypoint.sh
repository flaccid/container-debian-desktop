#!/bin/bash
# Populate the home directory from the skeleton on first run.
# Checks for the presence of ~/.config/xfce4 as a marker.
populate_home() {
    echo "First run: Populating /home/admin with default configuration..."
    cp -r /etc/skel/admin/. /home/admin/
    # XFCE requires autostart .desktop files to be executable
    chmod +x /home/admin/.config/autostart/*.desktop 2>/dev/null || true
}

# When running as root (the default in Docker/Kubernetes), drop privileges
# to the admin user via gosu after populating the home directory.
if [ "$(id -u)" = "0" ]; then
    if [ ! -d "/home/admin/.config/xfce4" ]; then
        populate_home
        chown -R admin:admin /home/admin
    fi
    exec gosu admin "$@"
# When already running as the admin user (e.g. exec'd into the pod), skip
# privilege drop but still populate if needed.
else
    if [ ! -d "/home/admin/.config/xfce4" ]; then
        populate_home
    fi
    exec "$@"
fi
