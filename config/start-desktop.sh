#!/bin/bash
#
# Orchestrator for the desktop container.
# Starts VNC, PulseAudio, audio proxy, and websockify instances.
set -e

# ------------------------------------------------------------------
# 1. Start TigerVNC (launches XFCE via ~/.vnc/xstartup)
# ------------------------------------------------------------------
echo "Starting TigerVNC on :1 (1920x1080, 24bpp)..."
vncserver :1 -geometry 1920x1080 -depth 24 -localhost no \
    -SecurityTypes None --I-KNOW-THIS-IS-INSECURE

# ------------------------------------------------------------------
# 2. Start PulseAudio (if not already running)
# ------------------------------------------------------------------
echo "Starting PulseAudio..."
pulseaudio --start --exit-idle-time=-1 --disallow-exit 2>/dev/null || true

# ------------------------------------------------------------------
# 3. Wait for PulseAudio, then load null-sink and TCP stream modules
# ------------------------------------------------------------------
echo "Waiting for PulseAudio to become ready..."
for i in $(seq 1 10); do
    if pactl info >/dev/null 2>&1; then
        echo "PulseAudio ready"
        break
    fi
    sleep 1
done

# The module configs in /etc/pulse/default.pa.d/ should load these
# automatically on startup, but we ensure they're loaded in case
# PulseAudio was already running (e.g., from XFCE autostart).
pactl load-module module-null-sink \
    sink_name=virtual_sink \
    sink_properties=device.description="Virtual_Sink" \
    2>/dev/null || true

pactl load-module module-simple-protocol-tcp \
    port=4711 \
    listen=127.0.0.1 format=s16le channels=2 rate=48000 \
    record=true playback=false \
    source=virtual_sink.monitor \
    2>/dev/null || true

pactl set-default-sink virtual_sink 2>/dev/null || true

echo "PulseAudio virtual sink ready"

# ------------------------------------------------------------------
# 4. Start audio proxy (GStreamer: PCM → WebM/Opus)
# ------------------------------------------------------------------
echo "Starting audio proxy on port 5711..."
/usr/local/bin/audio-proxy.sh -l 5711 &
AP_PID=$!
sleep 1
if kill -0 "$AP_PID" 2>/dev/null; then
    echo "Audio proxy started (PID $AP_PID)"
else
    echo "Warning: audio proxy failed to start — audio will not be available"
fi

# ------------------------------------------------------------------
# 5. Start audio websockify (WebSocket → audio proxy)
# ------------------------------------------------------------------
echo "Starting audio websockify on port 6902..."
websockify --cert /home/admin/.vnc/self.pem 6902 localhost:5711 &
AW_PID=$!
sleep 1
if kill -0 "$AW_PID" 2>/dev/null; then
    echo "Audio websockify started (PID $AW_PID)"
else
    echo "Warning: audio websockify failed to start — audio will not be available"
fi

# ------------------------------------------------------------------
# 6. Start VNC websockify (foreground — keeps container alive)
# ------------------------------------------------------------------
echo "Starting VNC websockify on port 6901..."
exec websockify --web /usr/share/novnc --cert /home/admin/.vnc/self.pem \
    6901 localhost:5901
