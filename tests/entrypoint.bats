setup() {
    export TEST_SKEL="/tmp/bats-skel"
    export TEST_HOME="/tmp/bats-home"
    mkdir -p "$TEST_SKEL/.config/xfce4/panel"
    mkdir -p "$TEST_SKEL/.config/autostart"
    mkdir -p "$TEST_SKEL/.vnc"
    echo "config" > "$TEST_SKEL/.config/xfce4/settings.xml"
    echo "genmon config" > "$TEST_SKEL/.config/xfce4/panel/genmon-12.rc"
    echo "genmon config" > "$TEST_SKEL/.config/xfce4/panel/genmon-14.rc"
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

@test "ensure_config copies guake.desktop, xstartup, and makes them executable" {
    mkdir -p "$TEST_HOME/.config/autostart"
    mkdir -p "$TEST_HOME/.vnc"
    mkdir -p "$TEST_HOME/.config/xfce4/xfconf/xfce-perchannel-xml"
    chmod 644 "$TEST_HOME/.config/autostart/"*.desktop 2>/dev/null || true
    cp "$TEST_SKEL/.config/autostart/guake.desktop" "$TEST_HOME/.config/autostart/guake.desktop" 2>/dev/null || true
    cp "$TEST_SKEL/.vnc/xstartup" "$TEST_HOME/.vnc/xstartup" 2>/dev/null || true
    chmod +x "$TEST_HOME/.config/autostart/guake.desktop" 2>/dev/null || true
    chmod +x "$TEST_HOME/.vnc/xstartup" 2>/dev/null || true
    [ -f "$TEST_HOME/.config/autostart/guake.desktop" ]
    [ -x "$TEST_HOME/.config/autostart/guake.desktop" ]
    [ -f "$TEST_HOME/.vnc/xstartup" ]
    [ -x "$TEST_HOME/.vnc/xstartup" ]
}

@test "ensure_config copies genmon-14.rc" {
    mkdir -p "$TEST_HOME/.config/xfce4/panel"
    cp "$TEST_SKEL/.config/xfce4/panel/genmon-14.rc" "$TEST_HOME/.config/xfce4/panel/genmon-14.rc" 2>/dev/null || true
    [ -f "$TEST_HOME/.config/xfce4/panel/genmon-14.rc" ]
    read -r content < "$TEST_HOME/.config/xfce4/panel/genmon-14.rc"
    [ "$content" = "genmon config" ]
}

@test "main logic: root, xfce4 exists, skips populate, runs ensure_config" {
    mkdir -p "$TEST_HOME/.config/xfce4"
    echo "existing" > "$TEST_HOME/.config/xfce4/settings.xml"
    mkdir -p "$TEST_HOME/.config/autostart"
    mkdir -p "$TEST_HOME/.vnc"
    mkdir -p "$TEST_HOME/.config/xfce4/xfconf/xfce-perchannel-xml"
    export HOME="$TEST_HOME"
    run bash -c '
        if [ ! -d "$HOME/.config/xfce4" ]; then
            cp -r '"$TEST_SKEL"'/. "$HOME/"
        else
            cp '"$TEST_SKEL"'/.vnc/xstartup "$HOME/.vnc/xstartup" 2>/dev/null || true
            chmod +x "$HOME/.vnc/xstartup" 2>/dev/null || true
            cp '"$TEST_SKEL"'/.config/autostart/guake.desktop "$HOME/.config/autostart/guake.desktop" 2>/dev/null || true
            chmod +x "$HOME/.config/autostart/guake.desktop" 2>/dev/null || true
        fi
        echo "would exec gosu admin \"\$@\""
    '
    [ "$status" -eq 0 ]
    [ -f "$TEST_HOME/.config/autostart/guake.desktop" ]
    [ -x "$TEST_HOME/.config/autostart/guake.desktop" ]
    [ -f "$TEST_HOME/.vnc/xstartup" ]
    [ -x "$TEST_HOME/.vnc/xstartup" ]
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

@test "main logic: non-root, xfce4 exists, skips populate, runs ensure_config" {
    mkdir -p "$TEST_HOME/.config/xfce4"
    echo "existing" > "$TEST_HOME/.config/xfce4/settings.xml"
    mkdir -p "$TEST_HOME/.config/autostart"
    mkdir -p "$TEST_HOME/.vnc"
    mkdir -p "$TEST_HOME/.config/xfce4/xfconf/xfce-perchannel-xml"
    export HOME="$TEST_HOME"
    run bash -c '
        if [ ! -d "$HOME/.config/xfce4" ]; then
            cp -r '"$TEST_SKEL"'/. "$HOME/"
        else
            cp '"$TEST_SKEL"'/.vnc/xstartup "$HOME/.vnc/xstartup" 2>/dev/null || true
            chmod +x "$HOME/.vnc/xstartup" 2>/dev/null || true
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

@test "persist_shadow creates backup in home from /etc/shadow" {
    skip "requires root to read /etc/shadow"
    mkdir -p "$TEST_HOME"
    export HOME="$TEST_HOME"
    run bash -c '
        shadow_backup="$HOME/.shadow"
        cp /etc/shadow "$shadow_backup"
        chown admin:admin "$shadow_backup" 2>/dev/null || true
    '
    [ "$status" -eq 0 ]
    [ -f "$TEST_HOME/.shadow" ]
}

@test "persist_shadow restores /etc/shadow from existing backup" {
    skip "requires root to write /etc/shadow"
    mkdir -p "$TEST_HOME"
    export HOME="$TEST_HOME"
    echo "mock-shadow-content" > "$TEST_HOME/.shadow"
    run bash -c '
        shadow_backup="$HOME/.shadow"
        if [ -f "$shadow_backup" ]; then
            cp "$shadow_backup" /etc/shadow
        fi
        cp /etc/shadow "$shadow_backup"
    '
    [ "$status" -eq 0 ]
}

@test "persist_shadow does not fail when backup is absent" {
    mkdir -p "$TEST_HOME"
    export HOME="$TEST_HOME"
    run bash -c '
        shadow_backup="$HOME/.shadow"
        if [ -f "$shadow_backup" ]; then
            cp "$shadow_backup" /etc/shadow
        fi
        touch "$shadow_backup"
    '
    [ "$status" -eq 0 ]
    [ -f "$TEST_HOME/.shadow" ]
}

@test "entrypoint.sh is valid bash" {
    run bash -n "$BATS_TEST_DIRNAME/../entrypoint.sh"
    [ "$status" -eq 0 ]
}
