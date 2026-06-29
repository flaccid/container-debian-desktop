setup() {
    export SKEL="/tmp/bats-reset-skel"
    export HOME="/tmp/bats-reset-home"
    export DISPLAY=":1"
    mkdir -p "$SKEL/.config/xfce4/panel"
    mkdir -p "$SKEL/.config/autostart"
    mkdir -p "$SKEL/.vnc"
    echo "xfce4-config" > "$SKEL/.config/xfce4/panel/panel.xml"
    echo "guake.desktop" > "$SKEL/.config/autostart/guake.desktop"
    chmod 644 "$SKEL/.config/autostart/guake.desktop"
    echo "vnc-cert" > "$SKEL/.vnc/self.pem"

    mkdir -p "$HOME/.config/xfce4/panel"
    mkdir -p "$HOME/.config/autostart"
    mkdir -p "$HOME/.vnc"
    echo "old-config" > "$HOME/.config/xfce4/panel/panel.xml"
    echo "old-guake.desktop" > "$HOME/.config/autostart/guake.desktop"
    chmod 644 "$HOME/.config/autostart/guake.desktop"
    echo "old-cert" > "$HOME/.vnc/self.pem"
}

teardown() {
    rm -rf "$SKEL" "$HOME"
}

@test "reset backs up existing xfce4 config" {
    run bash -c '
        if [ -d "$HOME/.config/xfce4" ]; then
            BACKUP_DIR="$HOME/.config/xfce4.bak.$(date +%Y%m%d%H%M%S)"
            mv "$HOME/.config/xfce4" "$BACKUP_DIR"
            [ -d "$BACKUP_DIR" ]
        fi
    '
    [ "$status" -eq 0 ]
    ls "$HOME/.config/" | grep -q "xfce4.bak."
}

@test "reset restores xfce4 config from skeleton" {
    run bash -c '
        mkdir -p "$HOME/.config"
        cp -r '"$SKEL"'/.config/xfce4 "$HOME/.config/"
        [ -f "$HOME/.config/xfce4/panel/panel.xml" ]
    '
    [ "$status" -eq 0 ]
    read -r content < "$HOME/.config/xfce4/panel/panel.xml"
    [ "$content" = "xfce4-config" ]
}

@test "reset restores autostart from skeleton" {
    run bash -c '
        mkdir -p "$HOME/.config"
        cp -r '"$SKEL"'/.config/autostart "$HOME/.config/" 2>/dev/null || true
        [ -f "$HOME/.config/autostart/guake.desktop" ]
    '
    [ "$status" -eq 0 ]
    read -r content < "$HOME/.config/autostart/guake.desktop"
    [ "$content" = "guake.desktop" ]
}

@test "reset makes autostart .desktop files executable" {
    run bash -c '
        mkdir -p "$HOME/.config"
        cp -r '"$SKEL"'/.config/autostart "$HOME/.config/" 2>/dev/null || true
        chmod +x "$HOME/.config/autostart/"*.desktop 2>/dev/null || true
        [ -x "$HOME/.config/autostart/guake.desktop" ]
    '
    [ "$status" -eq 0 ]
}

@test "reset restores VNC files from skeleton" {
    run bash -c '
        cp -r '"$SKEL"'/.vnc/* "$HOME/.vnc/" 2>/dev/null || true
        [ -f "$HOME/.vnc/self.pem" ]
    '
    [ "$status" -eq 0 ]
    read -r content < "$HOME/.vnc/self.pem"
    [ "$content" = "vnc-cert" ]
}

@test "reset-xfce4 script is valid bash" {
    run bash -n "$BATS_TEST_DIRNAME/../config/reset-xfce4"
    [ "$status" -eq 0 ]
}

@test "reset-xfce4 calls xfdesktop --arrange after restart" {
    grep -q 'xfdesktop --arrange' "$BATS_TEST_DIRNAME/../config/reset-xfce4"
}
