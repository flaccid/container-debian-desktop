#!/bin/bash
# Populate the home directory from the skeleton on first run.
# Checks for the presence of ~/.config/xfce4 as a marker.
populate_home() {
    echo "First run: Populating /home/admin with default configuration..."
    cp -r /etc/skel/admin/. /home/admin/
    # XFCE requires autostart .desktop files to be executable
    chmod +x /home/admin/.config/autostart/*.desktop 2>/dev/null || true
}

# Ensure key config files from the skeleton survive pod replacements
# on PVCs that already have a populated home directory.
ensure_config() {
    # Copy xstartup so XDG_RUNTIME_DIR and other critical settings
    # are always picked up on fresh VNC starts.
    cp /etc/skel/admin/.vnc/xstartup /home/admin/.vnc/xstartup 2>/dev/null || true
    chmod +x /home/admin/.vnc/xstartup 2>/dev/null || true

    # Copy the skeleton's guake.desktop so it survives pod replacement.
    cp /etc/skel/admin/.config/autostart/guake.desktop /home/admin/.config/autostart/guake.desktop 2>/dev/null || true
    chmod +x /home/admin/.config/autostart/guake.desktop 2>/dev/null || true

    # Copy xfce4-panel.xml to pick up new plugin definitions
    # (e.g. plugin-11 pulseaudio). The user can always customise
    # their panel afterward.
    cp /etc/skel/admin/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml \
       /home/admin/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml 2>/dev/null || true
}

# Persist /etc/shadow across pod restarts so the lock screen password
# (set via `passwd admin`) survives container/image replacement.
# `/etc/shadow` is copied to/from `/home/admin/.shadow` on the PVC.
persist_shadow() {
    local shadow_backup="/home/admin/.shadow"
    if [ -f "$shadow_backup" ]; then
        cp "$shadow_backup" /etc/shadow
    fi
    cp /etc/shadow "$shadow_backup"
    chown admin:admin "$shadow_backup"
}

# When running as root (the default in Docker/Kubernetes), drop privileges
# to the admin user via gosu after populating the home directory.
if [ "$(id -u)" = "0" ]; then
    if [ ! -d "/home/admin/.config/xfce4" ]; then
        populate_home
        chown -R admin:admin /home/admin
    else
        ensure_config
    fi
    # Create the XDG_RUNTIME_DIR for PulseAudio socket (required by the
    # XFCE PulseAudio panel plugin) and export it so gosu/admin inherit it.
    mkdir -p /run/user/1000 && chown admin:admin /run/user/1000
    export XDG_RUNTIME_DIR=/run/user/1000
    persist_shadow
    # Sync shadow to PVC every 2 minutes so password changes persist
    (
        while true; do
            sleep 120
            cp /etc/shadow /home/admin/.shadow 2>/dev/null || true
        done
    ) &
    exec gosu admin "$@"
# When already running as the admin user (e.g. exec'd into the pod), skip
# privilege drop but still populate if needed.
else
    if [ ! -d "/home/admin/.config/xfce4" ]; then
        populate_home
    else
        ensure_config
    fi
    exec "$@"
fi
