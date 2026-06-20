#!/bin/bash
# Smoke test: builds the image, starts a container, and validates the running environment.
set -euo pipefail

IMAGE_TAG="${1:-flaccid/debian-desktop:test-smoke}"
CONTAINER_NAME="debian-desktop-smoke-test"

cleanup() {
    echo "Cleaning up..."
    docker rm -f "$CONTAINER_NAME" 2>/dev/null || true
}
trap cleanup EXIT

echo "=== Smoke Test: $IMAGE_TAG ==="

# 1. Start the container
echo "--- Starting container ---"
docker run -d --name "$CONTAINER_NAME" "$IMAGE_TAG"

# 2. Wait for VNC to start (poll Xtigervnc process)
echo "--- Waiting for VNC (polling Xtigervnc) ---"
for i in $(seq 1 30); do
    if docker exec "$CONTAINER_NAME" pgrep Xtigervnc >/dev/null 2>&1; then
        echo "VNC started (attempt $i)"
        break
    fi
    if [ "$i" -eq 30 ]; then
        echo "FAIL: VNC did not start within 30 seconds"
        docker logs "$CONTAINER_NAME" 2>&1 || true
        exit 1
    fi
    sleep 1
done

# 3. Wait for websockify on 6901
echo "--- Waiting for websockify (port 6901) ---"
for i in $(seq 1 15); do
    if docker exec "$CONTAINER_NAME" sh -c '
        grep -q ":1AF5" /proc/net/tcp 2>/dev/null ||
        grep -q ":1AF5" /proc/net/tcp6 2>/dev/null
    '; then
        echo "Websockify listening (attempt $i)"
        break
    fi
    if [ "$i" -eq 15 ]; then
        echo "FAIL: Websockify did not start within 15 seconds"
        docker logs "$CONTAINER_NAME" 2>&1 || true
        exit 1
    fi
    sleep 1
done

# 4. Verify config files exist in the running container's home directory
echo "--- Checking config files ---"
docker exec "$CONTAINER_NAME" test -f /home/admin/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml \
    || { echo "FAIL: xsettings.xml not found"; docker exec "$CONTAINER_NAME" ls -la /home/admin/.config/xfce4/xfconf/xfce-perchannel-xml/ 2>/dev/null || true; exit 1; }

docker exec "$CONTAINER_NAME" test -f /home/admin/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml \
    || { echo "FAIL: xfce4-panel.xml not found"; exit 1; }

SCREENSAVER=$(docker exec "$CONTAINER_NAME" cat /home/admin/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-screensaver.xml 2>/dev/null)
if echo "$SCREENSAVER" | grep -q '"delay" type="int" value="60"'; then
    echo "xfce4-screensaver idle delay 60: OK"
else
    echo "FAIL: xfce4-screensaver idle delay 60 not found"
    echo "$SCREENSAVER"
    exit 1
fi

docker exec "$CONTAINER_NAME" test -f /home/admin/.config/autostart/disable-x11-screensaver.desktop \
    || { echo "FAIL: disable-x11-screensaver.desktop not found"; exit 1; }

echo "Config files present: OK"

# 5. Verify xsettings.xml values
echo "--- Checking xsettings.xml ---"
XSETTINGS=$(docker exec "$CONTAINER_NAME" cat /home/admin/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml)

if echo "$XSETTINGS" | grep -q 'FontName.*Ubuntu 11'; then
    echo "FontName Ubuntu 11: OK"
else
    echo "FAIL: FontName Ubuntu 11 not found"
    echo "$XSETTINGS"
    exit 1
fi

if echo "$XSETTINGS" | grep -q 'MonospaceFontName.*JetBrains Mono 10'; then
    echo "MonospaceFontName JetBrains Mono 10: OK"
else
    echo "FAIL: MonospaceFontName JetBrains Mono 10 not found"
    exit 1
fi

if echo "$XSETTINGS" | grep -q 'IconThemeName.*Papirus-Dark'; then
    echo "IconThemeName Papirus-Dark: OK"
else
    echo "FAIL: IconThemeName Papirus-Dark not found"
    exit 1
fi

if echo "$XSETTINGS" | grep -q 'ThemeName.*Adwaita-dark'; then
    echo "ThemeName Adwaita-dark: OK"
else
    echo "FAIL: ThemeName Adwaita-dark not found"
    exit 1
fi

# 6. Verify xfce4-panel.xml values
echo "--- Checking xfce4-panel.xml ---"
PANEL=$(docker exec "$CONTAINER_NAME" cat /home/admin/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml)

if echo "$PANEL" | grep -q '"icon-size" type="uint" value="32"'; then
    echo "icon-size 32: OK"
else
    echo "FAIL: icon-size 32 not found"
    echo "$PANEL"
    exit 1
fi

if echo "$PANEL" | grep -q '"size" type="uint" value="42"'; then
    echo "panel size 42: OK"
else
    echo "FAIL: panel size 42 not found"
    exit 1
fi

if echo "$PANEL" | grep -q 'applicationsmenu'; then
    echo "Plugin applicationsmenu: OK"
else
    echo "FAIL: applicationsmenu plugin not found"
    exit 1
fi

# 7. Verify wrapper scripts work
echo "--- Checking wrapper scripts ---"
docker exec "$CONTAINER_NAME" test -x /usr/local/bin/google-chrome \
    && docker exec "$CONTAINER_NAME" test -x /usr/local/bin/signal-desktop \
    && docker exec "$CONTAINER_NAME" test -x /usr/local/bin/code \
    && docker exec "$CONTAINER_NAME" test -x /usr/local/bin/disable-x11-screensaver.sh \
    || { echo "FAIL: wrapper scripts not executable"; exit 1; }
echo "Wrapper scripts executable: OK"

# 8. Verify audio components
echo "--- Checking audio components ---"
docker exec "$CONTAINER_NAME" test -f /usr/share/novnc/audio-plugin.js \
    || { echo "FAIL: audio-plugin.js not found"; exit 1; }
echo "audio-plugin.js present: OK"

docker exec "$CONTAINER_NAME" test -x /usr/local/bin/start-desktop.sh \
    || { echo "FAIL: start-desktop.sh not executable"; exit 1; }
echo "start-desktop.sh executable: OK"

docker exec "$CONTAINER_NAME" test -x /usr/local/bin/audio-proxy.sh \
    || { echo "FAIL: audio-proxy.sh not executable"; exit 1; }
echo "audio-proxy.sh executable: OK"

docker exec "$CONTAINER_NAME" test -f /etc/pulse/default.pa.d/virtual-sink.pa \
    || { echo "FAIL: virtual-sink.pa not found"; exit 1; }
echo "PulseAudio virtual-sink config: OK"

docker exec "$CONTAINER_NAME" test -f /etc/pulse/default.pa.d/audio-stream.pa \
    || { echo "FAIL: audio-stream.pa not found"; exit 1; }
echo "PulseAudio audio-stream config: OK"

AUDIO_VNC=$(docker exec "$CONTAINER_NAME" grep -c 'audio-plugin.js' /usr/share/novnc/vnc.html || true)
if [ "$AUDIO_VNC" -ge 1 ]; then
    echo "vnc.html includes audio-plugin.js: OK"
else
    echo "FAIL: vnc.html does not include audio-plugin.js"
    exit 1
fi

# 9. Verify favicon and PWA manifest
echo "--- Checking favicon and PWA ---"
docker exec "$CONTAINER_NAME" test -f /usr/share/novnc/manifest.json \
    || { echo "FAIL: manifest.json not found"; exit 1; }
echo "manifest.json present: OK"

docker exec "$CONTAINER_NAME" test -f /usr/share/novnc/icon-192.png \
    || { echo "FAIL: icon-192.png not found"; exit 1; }
echo "PWA icon 192x192 present: OK"

docker exec "$CONTAINER_NAME" test -f /usr/share/novnc/icon-512.png \
    || { echo "FAIL: icon-512.png not found"; exit 1; }
echo "PWA icon 512x512 present: OK"

FAVICON_VNC=$(docker exec "$CONTAINER_NAME" grep -c 'rel="icon".*openlogo-debianV2.svg' /usr/share/novnc/vnc.html || true)
if [ "$FAVICON_VNC" -ge 1 ]; then
    echo "vnc.html includes favicon link: OK"
else
    echo "FAIL: vnc.html does not include favicon link"
    exit 1
fi

MANIFEST_VNC=$(docker exec "$CONTAINER_NAME" grep -c 'rel="manifest".*manifest.json' /usr/share/novnc/vnc.html || true)
if [ "$MANIFEST_VNC" -ge 1 ]; then
    echo "vnc.html includes manifest link: OK"
else
    echo "FAIL: vnc.html does not include manifest link"
    exit 1
fi

FAVICON_VNCA=$(docker exec "$CONTAINER_NAME" grep -c 'rel="icon".*openlogo-debianV2.svg' /usr/share/novnc/vnc_auto.html || true)
if [ "$FAVICON_VNCA" -ge 1 ]; then
    echo "vnc_auto.html includes favicon link: OK"
else
    echo "FAIL: vnc_auto.html does not include favicon link"
    exit 1
fi

MANIFEST_VNCA=$(docker exec "$CONTAINER_NAME" grep -c 'rel="manifest".*manifest.json' /usr/share/novnc/vnc_auto.html || true)
if [ "$MANIFEST_VNCA" -ge 1 ]; then
    echo "vnc_auto.html includes manifest link: OK"
else
    echo "FAIL: vnc_auto.html does not include manifest link"
    exit 1
fi

# 10. Verify noVNC redirect
echo "--- Checking noVNC index.html ---"
NOVNC_INDEX=$(docker exec "$CONTAINER_NAME" cat /usr/share/novnc/index.html)
if echo "$NOVNC_INDEX" | grep -q "resize=remote"; then
    echo "noVNC resize=remote: OK"
else
    echo "FAIL: noVNC resize=remote not found"
    exit 1
fi

echo ""
echo "=== ALL SMOKE TESTS PASSED ==="
