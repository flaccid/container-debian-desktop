#!/bin/bash
if [ "$(id -u)" = "0" ]; then
    if [ ! -d "/home/admin/.config/xfce4" ]; then
        echo "First run: Populating /home/admin with default configuration..."
        cp -r /etc/skel/admin/. /home/admin/
        chown -R admin:admin /home/admin
    fi
    exec gosu admin "$@"
else
    if [ ! -d "/home/admin/.config/xfce4" ]; then
        echo "First run: Populating /home/admin with default configuration..."
        cp -r /etc/skel/admin/. /home/admin/
    fi
    exec "$@"
fi
