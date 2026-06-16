#!/bin/bash
# If the user's home directory is empty (e.g., first run with a new PVC),
# populate it with the default configuration from /etc/skel.
if [ ! -f "/home/admin/.vnc/xstartup" ]; then
    echo "First run: Populating /home/admin with default configuration..."
    cp -r /etc/skel/admin/. /home/admin/
    chown -R admin:admin /home/admin
fi

# Execute the main container command (passed as arguments to this script)
exec "$@"
