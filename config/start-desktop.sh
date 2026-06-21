#!/bin/bash
#
# Orchestrator for the desktop container.
# Starts PulseAudio, VNC, audio proxy, and websockify instances.
set -e

# PulseAudio needs XDG_RUNTIME_DIR for its socket path. Set it early
# so both PulseAudio and the XFCE session (via xstartup) get it.
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

# ------------------------------------------------------------------
# 1. Start PulseAudio (before VNC so the panel plugin can connect)
# ------------------------------------------------------------------
echo "Starting PulseAudio..."
pulseaudio --start --exit-idle-time=-1 --disallow-exit 2>/dev/null || true

# ------------------------------------------------------------------
# 2. Start TigerVNC (launches XFCE via ~/.vnc/xstartup)
# ------------------------------------------------------------------
echo "Starting TigerVNC on :1 (1920x1080, 24bpp)..."
vncserver :1 -geometry 1920x1080 -depth 24 -localhost no \
    -SecurityTypes None --I-KNOW-THIS-IS-INSECURE

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

# Create a dummy source for the PulseAudio panel plugin's mic/input tab.
# Without this, the default source is virtual_sink.monitor, so muting the
# "mic" in the panel would mute the audio stream. This dummy source is
# completely separate — muting it has no effect on audio.
pactl load-module module-null-sink \
    sink_name=dummy_mic \
    sink_properties=device.description="Dummy_Mic" \
    2>/dev/null || true
pactl set-default-source dummy_mic.monitor 2>/dev/null || true
# Mute the dummy mic by default — removes any doubt that it is not a real mic.
pactl set-source-mute dummy_mic.monitor 1 2>/dev/null || true

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
websockify 6902 localhost:5711 &
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
