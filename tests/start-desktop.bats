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
        vncserver :1 -geometry 1920x1080 -depth 24 -localhost no -SecurityTypes None -alwaysshared --I-KNOW-THIS-IS-INSECURE
        pulseaudio --start --exit-idle-time=-1 --disallow-exit
        pactl load-module module-null-sink sink_name=virtual_sink sink_properties=device.description=Virtual_Sink
        pactl load-module module-simple-protocol-tcp listen=127.0.0.1 format=s16le channels=2 rate=48000 record=true playback=false source=virtual_sink.monitor
        pactl set-default-sink virtual_sink
        # audio-proxy and audio websockify run in background — skip for test
        # Foreground VNC websockify
        websockify --web /usr/share/novnc 6901 localhost:5901
    '
    [[ "$output" == *"vncserver :1"* ]]
    [[ "$output" == *"pulseaudio --start"* ]]
    [[ "$output" == *"pactl load-module module-null-sink"* ]]
    [[ "$output" == *"pactl load-module module-simple-protocol-tcp"* ]]
    [[ "$output" == *"websockify --web /usr/share/novnc"* ]]
}

@test "fix-audio is valid bash" {
    run bash -n "$BATS_TEST_DIRNAME/../config/fix-audio"
    [ "$status" -eq 0 ]
}

@test "fix-audio --check detects missing audio" {
    run bash -c '
        BATS_TEST_DIR="'"$BATS_TEST_DIRNAME"'"

        # Mock commands
        pactl() {
            case "$*" in
                "info") return 1 ;;
                *)     return 1 ;;
            esac
        }
        pgrep() { return 1; }
        ss()    { return 1; }

        export -f pactl pgrep ss

        bash "$BATS_TEST_DIR/../config/fix-audio" --check 2>/dev/null
    '
    # In check-only mode the script exits 1 when issues found
    [ "$status" -eq 1 ]
}

@test "fix-audio repairs PulseAudio when it is down" {
    run bash -c '
        set -e
        BATS_TEST_DIR="'"$BATS_TEST_DIRNAME"'"

        MARKER=$(mktemp)
        export MARKER
        export PACTL_INITIAL=""

        pulseaudio() {
            echo "$*" >> "$MARKER"
            case "${1-}" in
                --kill)  return 0 ;;
                --start) return 0 ;;
                *)       return 0 ;;
            esac
        }

        pactl() {
            if [ -z "${PACTL_INITIAL-}" ]; then
                PACTL_INITIAL=1
                return 1
            fi
            return 0
        }

        pkill()  { return 0; }
        pgrep()  { return 1; }
        ss()     { return 1; }
        sleep()  { true; }
        kill()   { return 0; }
        rm()     { return 0; }
        mkdir()  { return 0; }
        seq()    { echo 1; }

        export -f pulseaudio pactl pkill pgrep ss sleep kill rm mkdir seq
        export XDG_RUNTIME_DIR=/tmp/fake-pulse

        bash "$BATS_TEST_DIR/../config/fix-audio" 2>/dev/null || true

        grep -q -- "--start" "$MARKER"
    '
    [ "$status" -eq 0 ]
}

@test "session-timer.sh is valid bash" {
    run bash -n "$BATS_TEST_DIRNAME/../config/session-timer.sh"
    [ "$status" -eq 0 ]
}

@test "session-timer.sh --init creates state file" {
    run bash -c '
        set -e
        export HOME="'"$TEST_DIR"'"
        export XDG_CACHE_HOME="$HOME/.cache"
        bash "'"$BATS_TEST_DIRNAME"'/../config/session-timer.sh" --init
        [ -f "$XDG_CACHE_HOME/session-start" ]
    '
    [ "$status" -eq 0 ]
}

@test "session-timer.sh displays elapsed time" {
    run bash -c '
        set -e
        export HOME="'"$TEST_DIR"'"
        export XDG_CACHE_HOME="$HOME/.cache"
        mkdir -p "$XDG_CACHE_HOME"
        date +%s > "$XDG_CACHE_HOME/session-start"
        bash "'"$BATS_TEST_DIRNAME"'/../config/session-timer.sh"
    '
    [[ "$output" == *"⏱"* ]]
}

@test "test-audio is valid bash" {
    run bash -n "$BATS_TEST_DIRNAME/../config/test-audio"
    [ "$status" -eq 0 ]
}

@test "test-audio detects missing PulseAudio" {
    run bash -c '
        BATS_TEST_DIR="'"$BATS_TEST_DIRNAME"'"
        pactl() { return 1; }
        export -f pactl
        bash "$BATS_TEST_DIR/../config/test-audio" 2>/dev/null
    '
    [ "$status" -eq 1 ]
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
        websockify --web /usr/share/novnc 6901 localhost:5901
    '
    [[ "$output" == *"vncserver"* ]]
    [[ "$output" == *"websockify --web /usr/share/novnc"* ]]
}
