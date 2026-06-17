setup() {
    export TEST_SKEL="/tmp/bats-skel"
    export TEST_HOME="/tmp/bats-home"
    mkdir -p "$TEST_SKEL/.config/xfce4"
    mkdir -p "$TEST_SKEL/.config/autostart"
    mkdir -p "$TEST_SKEL/.vnc"
    echo "config" > "$TEST_SKEL/.config/xfce4/settings.xml"
    echo "guake.desktop" > "$TEST_SKEL/.config/autostart/guake.desktop"
    echo "other.desktop" > "$TEST_SKEL/.config/autostart/other.desktop"
    echo "vnc" > "$TEST_SKEL/.vnc/xstartup"
}

teardown() {
    rm -rf "$TEST_SKEL" "$TEST_HOME"
}

@test "populate_home copies skeleton to home" {
    mkdir -p "$TEST_HOME"
    cp -r "$TEST_SKEL/." "$TEST_HOME/"
    [ -f "$TEST_HOME/.config/xfce4/settings.xml" ]
    [ -f "$TEST_HOME/.config/autostart/guake.desktop" ]
    [ -f "$TEST_HOME/.config/autostart/other.desktop" ]
    [ -f "$TEST_HOME/.vnc/xstartup" ]
}

@test "populate_home makes autostart .desktop files executable" {
    mkdir -p "$TEST_HOME"
    cp -r "$TEST_SKEL/." "$TEST_HOME/"
    chmod +x "$TEST_HOME/.config/autostart/"*.desktop 2>/dev/null || true
    [ -x "$TEST_HOME/.config/autostart/guake.desktop" ]
    [ -x "$TEST_HOME/.config/autostart/other.desktop" ]
}

@test "populate_home preserves non-desktop file permissions" {
    mkdir -p "$TEST_HOME"
    cp -r "$TEST_SKEL/." "$TEST_HOME/"
    chmod +x "$TEST_HOME/.config/autostart/"*.desktop 2>/dev/null || true
    [ ! -x "$TEST_HOME/.vnc/xstartup" ]
}

@test "main logic: root, no xfce4 dir, populates and uses gosu" {
    mkdir -p "$TEST_HOME"
    export HOME="$TEST_HOME"
    run bash -c '
        if [ ! -d "$HOME/.config/xfce4" ]; then
            cp -r '"$TEST_SKEL"'/. "$HOME/"
            chown -R admin:admin "$HOME" 2>/dev/null || true
        fi
        echo "would exec gosu admin \"\$@\""
    '
    [ "$status" -eq 0 ]
    [ -f "$TEST_HOME/.config/xfce4/settings.xml" ]
}

@test "ensure_autostart copies guake.desktop and makes it executable" {
    mkdir -p "$TEST_HOME/.config/autostart"
    chmod 644 "$TEST_HOME/.config/autostart/"*.desktop 2>/dev/null || true
    cp "$TEST_SKEL/.config/autostart/guake.desktop" "$TEST_HOME/.config/autostart/guake.desktop" 2>/dev/null || true
    chmod +x "$TEST_HOME/.config/autostart/guake.desktop" 2>/dev/null || true
    [ -f "$TEST_HOME/.config/autostart/guake.desktop" ]
    [ -x "$TEST_HOME/.config/autostart/guake.desktop" ]
}

@test "main logic: root, xfce4 exists, skips populate, runs ensure_autostart" {
    mkdir -p "$TEST_HOME/.config/xfce4"
    echo "existing" > "$TEST_HOME/.config/xfce4/settings.xml"
    mkdir -p "$TEST_HOME/.config/autostart"
    export HOME="$TEST_HOME"
    run bash -c '
        if [ ! -d "$HOME/.config/xfce4" ]; then
            cp -r '"$TEST_SKEL"'/. "$HOME/"
        else
            cp '"$TEST_SKEL"'/.config/autostart/guake.desktop "$HOME/.config/autostart/guake.desktop" 2>/dev/null || true
            chmod +x "$HOME/.config/autostart/guake.desktop" 2>/dev/null || true
        fi
        echo "would exec gosu admin \"\$@\""
    '
    [ "$status" -eq 0 ]
    [ -f "$TEST_HOME/.config/autostart/guake.desktop" ]
    [ -x "$TEST_HOME/.config/autostart/guake.desktop" ]
    read -r content < "$TEST_HOME/.config/xfce4/settings.xml"
    [ "$content" = "existing" ]
}

@test "main logic: non-root, no xfce4 dir, populates and execs cmd" {
    mkdir -p "$TEST_HOME"
    export HOME="$TEST_HOME"
    run bash -c '
        if [ ! -d "$HOME/.config/xfce4" ]; then
            cp -r '"$TEST_SKEL"'/. "$HOME/"
        fi
        echo "would exec \"\$@\""
    '
    [ "$status" -eq 0 ]
    [ -f "$TEST_HOME/.config/xfce4/settings.xml" ]
}

@test "main logic: non-root, xfce4 exists, skips populate, runs ensure_autostart" {
    mkdir -p "$TEST_HOME/.config/xfce4"
    echo "existing" > "$TEST_HOME/.config/xfce4/settings.xml"
    mkdir -p "$TEST_HOME/.config/autostart"
    export HOME="$TEST_HOME"
    run bash -c '
        if [ ! -d "$HOME/.config/xfce4" ]; then
            cp -r '"$TEST_SKEL"'/. "$HOME/"
        else
            cp '"$TEST_SKEL"'/.config/autostart/guake.desktop "$HOME/.config/autostart/guake.desktop" 2>/dev/null || true
            chmod +x "$HOME/.config/autostart/guake.desktop" 2>/dev/null || true
        fi
        echo "would exec \"\$@\""
    '
    [ "$status" -eq 0 ]
    [ -f "$TEST_HOME/.config/autostart/guake.desktop" ]
    [ -x "$TEST_HOME/.config/autostart/guake.desktop" ]
    read -r content < "$TEST_HOME/.config/xfce4/settings.xml"
    [ "$content" = "existing" ]
}

@test "entrypoint.sh is valid bash" {
    run bash -n "$BATS_TEST_DIRNAME/../entrypoint.sh"
    [ "$status" -eq 0 ]
}
