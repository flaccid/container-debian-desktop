#!/bin/bash
populate_home() {
    echo "First run: Populating /home/admin with default configuration..."
    cp -r /etc/skel/admin/. /home/admin/
    chmod +x /home/admin/.config/autostart/*.desktop 2>/dev/null || true
}

if [ "$(id -u)" = "0" ]; then
    if [ ! -d "/home/admin/.config/xfce4" ]; then
        populate_home
        chown -R admin:admin /home/admin
    fi
    exec gosu admin "$@"
else
    if [ ! -d "/home/admin/.config/xfce4" ]; then
        populate_home
    fi
    exec "$@"
fi
