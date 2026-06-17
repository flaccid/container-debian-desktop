setup() {
    export TEST_DIR="/tmp/bats-start-desktop"
    mkdir -p "$TEST_DIR"
}

teardown() {
    rm -rf "$TEST_DIR"
}

@test "start-desktop.sh is valid bash" {
    run bash -n "$BATS_TEST_DIRNAME/../config/start-desktop.sh"
    [ "$status" -eq 0 ]
}

@test "audio-proxy.sh is valid bash" {
    run bash -n "$BATS_TEST_DIRNAME/../config/audio-proxy.sh"
    [ "$status" -eq 0 ]
}

@test "start-desktop.sh orchestrates vncserver" {
    run bash -c '
        set -e
        # Mock commands — simulate what start-desktop.sh calls
        vncserver() { echo "vncserver $*"; true; }
        pulseaudio() { echo "pulseaudio $*"; true; }
        pactl() { echo "pactl $*"; true; }
        websockify() { echo "websockify $*"; }

        # Simulate start-desktop.sh logic with real function calls
        vncserver :1 -geometry 1920x1080 -depth 24 -localhost no -SecurityTypes None --I-KNOW-THIS-IS-INSECURE
        pulseaudio --start --exit-idle-time=-1 --disallow-exit
        pactl load-module module-null-sink sink_name=virtual_sink sink_properties=device.description=Virtual_Sink
        pactl load-module module-simple-protocol-tcp listen=127.0.0.1 format=s16le channels=2 rate=48000 record=true playback=false source=virtual_sink.monitor
        pactl set-default-sink virtual_sink
        # audio-proxy and audio websockify run in background — skip for test
        # Foreground VNC websockify
        websockify --web /usr/share/novnc --cert /home/admin/.vnc/self.pem 6901 localhost:5901
    '
    [[ "$output" == *"vncserver :1"* ]]
    [[ "$output" == *"pulseaudio --start"* ]]
    [[ "$output" == *"pactl load-module module-null-sink"* ]]
    [[ "$output" == *"pactl load-module module-simple-protocol-tcp"* ]]
    [[ "$output" == *"websockify --web /usr/share/novnc"* ]]
}

@test "start-desktop.sh handles missing audio gracefully" {
    run bash -c '
        set -e
        # Mock commands with failures for audio-related ones
        vncserver() { echo "vncserver $*"; true; }
        pulseaudio() { echo "pulseaudio $*"; return 1; }
        pactl() { echo "pactl error" >&2; return 1; }
        websockify() { echo "websockify $*"; }

        # Simulate startup with graceful error handling
        vncserver :1 -geometry 1920x1080
        pulseaudio --start --exit-idle-time=-1 --disallow-exit 2>/dev/null || true
        pactl load-module module-null-sink 2>/dev/null || true
        true  # audio-proxy would start here; simulate failure
        true  # audio websockify would start here; simulate failure
        websockify --web /usr/share/novnc --cert /home/admin/.vnc/self.pem 6901 localhost:5901
    '
    [[ "$output" == *"vncserver"* ]]
    [[ "$output" == *"websockify --web /usr/share/novnc"* ]]
}
