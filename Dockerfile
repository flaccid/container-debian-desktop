FROM debian:trixie-slim

# Prevent interactive prompts during apt
ENV DEBIAN_FRONTEND=noninteractive

# Add third-party apt repos (VS Code, Google Chrome, Signal)
ARG GIT_INFO="unknown"
RUN apt-get update     && apt-get install -y --no-install-recommends \
        curl \
        ca-certificates \
        gpg \
        apt-transport-https \
    && rm -rf /var/lib/apt/lists/* \
    && install -d /usr/share/keyrings \
    && curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /usr/share/keyrings/microsoft-archive-keyring.gpg \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft-archive-keyring.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list \
    && curl -fsSL https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /usr/share/keyrings/google-chrome-keyring.gpg \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome-keyring.gpg] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list \
    && curl -fsSL https://updates.signal.org/desktop/apt/keys.asc | gpg --dearmor -o /usr/share/keyrings/signal-desktop-keyring.gpg \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/signal-desktop-keyring.gpg] https://updates.signal.org/desktop/apt xenial main" > /etc/apt/sources.list.d/signal-desktop.list \
    && date > /etc/lastbuilt \
    && echo "$GIT_INFO" > /etc/gitinfo

# Install desktop environment, VNC server, noVNC, and other utilities
RUN apt-get update && apt-get install -y --no-install-recommends \
    gosu \
    psmisc \
    xfce4 \
    xfce4-taskmanager \
    xfce4-terminal \
    tigervnc-standalone-server \
    tigervnc-common \
    novnc \
    websockify \
    sudo \
    curl \
    wget \
    ca-certificates \
    dbus-x11 \
    openssl \
    adwaita-icon-theme \
    awscli \
    papirus-icon-theme \
    librsvg2-common \
    gnome-themes-extra \
    gsettings-desktop-schemas \
    dconf-cli \
    guake \
    code \
    google-chrome-stable \
    signal-desktop \
    fonts-cantarell \
    fonts-jetbrains-mono \
    fonts-noto-color-emoji \
    fonts-noto-core \
    fonts-noto-cjk \
    unzip \
    xclip \
    git \
    gh \
    golang-go \
    kubectx \
    make \
    pulseaudio \
    pulseaudio-utils \
    pavucontrol \
    socat \
    gstreamer1.0-tools \
    gstreamer1.0-plugins-base \
    gstreamer1.0-plugins-good \
    gstreamer1.0-plugins-bad \
    xfce4-screensaver \
    apt-utils \
    bash-completion \
    bind9-host \
    build-essential \
    bwm-ng \
    bzip2 \
    cmake \
    cowsay \
    dnsutils \
    file \
    gnupg2 \
    htop \
    iproute2 \
    iputils-ping \
    joe \
    jq \
    less \
    locales \
    lsb-release \
    man \
    nano \
    net-tools \
    netcat-openbsd \
    procps \
    pwgen \
    python-is-python3 \
    python3-pip \
    screen \
    telnet \
    tmux \
    traceroute \
    tree \
    tzdata \
    vim \
    xz-utils \
    zip \
    librsvg2-bin \
    zsh \
    && rm -rf /var/lib/apt/lists/*

# Install the Ubuntu font family (not packaged in Trixie)
RUN curl -fsSL -o /tmp/fonts-ubuntu.deb \
    "http://ftp.debian.org/debian/pool/non-free/f/fonts-ubuntu/fonts-ubuntu_0.83-6_all.deb" \
    && dpkg -i /tmp/fonts-ubuntu.deb \
    && rm /tmp/fonts-ubuntu.deb

# Install opencode CLI
RUN curl -fsSL "https://github.com/anomalyco/opencode/releases/download/v1.17.7/opencode-linux-x64.tar.gz" -o /tmp/opencode.tar.gz \
    && tar xzf /tmp/opencode.tar.gz -C /usr/local/bin/ opencode \
    && chmod +x /usr/local/bin/opencode \
    && rm /tmp/opencode.tar.gz

# Install CLI tools: helm, kubectl, k9s, glab, terraform
RUN curl -fsSL https://get.helm.sh/helm-v3.21.1-linux-amd64.tar.gz | tar xz -C /usr/local/bin --strip-components=1 linux-amd64/helm \
    && curl -fsSL -o /usr/local/bin/kubectl "https://dl.k8s.io/release/v1.36.2/bin/linux/amd64/kubectl" \
    && chmod +x /usr/local/bin/kubectl \
    && curl -fsSL -o /tmp/k9s.tar.gz "https://github.com/derailed/k9s/releases/download/v0.51.0/k9s_Linux_amd64.tar.gz" \
    && tar xzf /tmp/k9s.tar.gz -C /usr/local/bin k9s \
    && rm /tmp/k9s.tar.gz \
    && curl -fsSL -o /tmp/glab.tar.gz "https://gitlab.com/gitlab-org/cli/-/releases/v1.103.0/downloads/glab_1.103.0_linux_amd64.tar.gz" \
    && tar xzf /tmp/glab.tar.gz --strip-components=1 -C /usr/local/bin bin/glab \
    && rm /tmp/glab.tar.gz \
    && curl -fsSL -o /tmp/terraform.zip "https://releases.hashicorp.com/terraform/1.15.6/terraform_1.15.6_linux_amd64.zip" \
    && unzip -o /tmp/terraform.zip -d /usr/local/bin \
    && rm /tmp/terraform.zip

# Install Google Cloud SDK (apt repo), taws, tfswitch, yq
RUN curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" > /etc/apt/sources.list.d/google-cloud-sdk.list \
    && apt-get update && apt-get install -y --no-install-recommends google-cloud-cli \
    && rm -rf /var/lib/apt/lists/* \
    && curl -fsSL -o /tmp/taws.tar.gz "https://github.com/huseyinbabal/taws/releases/download/v1.3.0-rc.8/taws-x86_64-unknown-linux-musl.tar.gz" \
    && tar xzf /tmp/taws.tar.gz -C /usr/local/bin taws \
    && rm /tmp/taws.tar.gz \
    && curl -fsSL -o /tmp/tfswitch.tar.gz "https://github.com/warrensbox/terraform-switcher/releases/download/v1.19.0/terraform-switcher_v1.19.0_linux_amd64.tar.gz" \
    && tar xzf /tmp/tfswitch.tar.gz -C /usr/local/bin tfswitch \
    && rm /tmp/tfswitch.tar.gz \
    && curl -fsSL -o /usr/local/bin/yq "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64" \
    && chmod +x /usr/local/bin/yq

# Create wrapper scripts for apps that need --no-sandbox in containers
RUN { \
      echo '#!/bin/bash'; \
      echo 'exec /opt/google/chrome/google-chrome --no-sandbox --disable-gpu --disable-dev-shm-usage --test-type "$@"'; \
    } > /usr/local/bin/google-chrome \
    && chmod +x /usr/local/bin/google-chrome \
    && ln -sf google-chrome /usr/local/bin/google-chrome-stable \
    && { \
         echo '#!/bin/bash'; \
         echo 'exec /opt/Signal/signal-desktop --no-sandbox "$@"'; \
       } > /usr/local/bin/signal-desktop \
    && chmod +x /usr/local/bin/signal-desktop \
    && { \
         echo '#!/bin/bash'; \
         echo 'exec /usr/share/code/code --no-sandbox "$@"'; \
       } > /usr/local/bin/code \
    && chmod +x /usr/local/bin/code

# Point desktop menu entries at our wrappers so menu clicks also use --no-sandbox
RUN sed -i 's|^Exec=/usr/bin/google-chrome-stable|Exec=/usr/local/bin/google-chrome|' /usr/share/applications/google-chrome.desktop \
    && sed -i 's|^Exec=/opt/Signal/signal-desktop|Exec=/usr/local/bin/signal-desktop|' /usr/share/applications/signal-desktop.desktop \
    && sed -i 's|^Exec=/usr/share/code/code|Exec=/usr/local/bin/code|' /usr/share/applications/code.desktop

# Create a non-root user and template home directory
ARG USERNAME=admin
ARG USER_UID=1000
ARG USER_GID=1000
RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m -s /bin/bash -d /home/$USERNAME -k /etc/skel $USERNAME \
    && echo "$USERNAME ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME \
    && mkdir -p /etc/skel/admin/.config \
    && chown -R $USERNAME:$USERNAME /etc/skel/admin

# Patch noVNC to default to remote resizing
RUN sed -i "s/UI.initSetting('resize', 'off');/UI.initSetting('resize', 'remote');/g" /usr/share/novnc/app/ui.js

# Create a default index.html to redirect to vnc_auto.html with remote resizing enabled
RUN echo '<meta http-equiv="refresh" content="0; url=vnc_auto.html?resize=remote">' > /usr/share/novnc/index.html

# Audio plugin, PWA branding, dark theme, and service worker for noVNC
COPY config/audio-plugin.js /usr/share/novnc/audio-plugin.js
COPY config/openlogo-debianV2.svg /usr/share/novnc/openlogo-debianV2.svg
COPY config/Debian-OpenLogo.svg /usr/share/novnc/Debian-OpenLogo.svg
COPY config/manifest.json /usr/share/novnc/manifest.json
COPY config/novnc-dark.css /usr/share/novnc/novnc-dark.css
COPY config/sw.js /usr/share/novnc/sw.js
RUN rsvg-convert -w 192 -h 192 -o /usr/share/novnc/icon-192.png /usr/share/novnc/openlogo-debianV2.svg && \
    rsvg-convert -w 512 -h 512 -o /usr/share/novnc/icon-512.png /usr/share/novnc/openlogo-debianV2.svg
RUN set -e; \
    \
    # 1. Replace original novnc.ico favicon with Debian SVG in both files
    sed -i 's|<link rel="icon" type="image/x-icon" href="app/images/icons/novnc.ico">|<link rel="icon" type="image/svg+xml" href="openlogo-debianV2.svg">|' \
        /usr/share/novnc/vnc.html /usr/share/novnc/vnc_auto.html; \
    \
    # 2. Insert audio plugin before favicon link and NVUI after UI import (vnc.html only)
    sed -i 's|<link rel="icon" type="image/svg+xml" href="openlogo-debianV2.svg">|<script type="module" src="audio-plugin.js"></script>\n&|' /usr/share/novnc/vnc.html; \
    sed -i '/import UI from "\.\/app\/ui\.js";/a\        window.NVUI = UI;' /usr/share/novnc/vnc.html; \
    \
    # 3. Add all remaining tags before </head> in both files
    #    (manifest, theme-color, apple-touch-icon, dark CSS, service worker)
    for f in /usr/share/novnc/vnc.html /usr/share/novnc/vnc_auto.html; do \
        sed -i 's|</head>|<link rel="manifest" href="manifest.json">\n<meta name="theme-color" content="#D70751">\n<meta name="apple-mobile-web-app-capable" content="yes">\n<meta name="apple-mobile-web-app-title" content="Debian Desktop">\n<link rel="apple-touch-icon" href="icon-192.png">\n<link rel="stylesheet" href="novnc-dark.css">\n<script>if("serviceWorker"in navigator){window.addEventListener("load",function(){navigator.serviceWorker.register("/sw.js")})}</script>\n</head>|' "$f"; \
    done

# Download wallpaper
RUN mkdir -p /usr/share/backgrounds && \
    curl -fsSL -o /usr/share/backgrounds/wallpaper.jpg \
    "https://images.unsplash.com/photo-1483982258113-b72862e6cff6?ixlib=rb-4.1.0&q=85&fm=jpg&crop=entropy&cs=srgb&dl=rosie-sun-1L71sPT5XKc-unsplash.jpg"

# Copy pre-configured XFCE settings into the skeleton directory
RUN echo "build_id: $(date +%s)" > /etc/config_id
COPY --chown=admin:admin config/xfce4 /etc/skel/admin/.config/xfce4

# Configure PulseAudio for audio streaming to the browser
# virtual-sink.pa  — creates a null sink that apps output to
# audio-stream.pa  — streams raw PCM from the null sink to TCP (port 4711)
COPY config/pulse/default.pa.d/virtual-sink.pa /etc/pulse/default.pa.d/virtual-sink.pa
COPY config/pulse/default.pa.d/audio-stream.pa /etc/pulse/default.pa.d/audio-stream.pa

# Setup VNC configuration in the skeleton directory
RUN mkdir -p /etc/skel/admin/.vnc \
    && mkdir -p /etc/skel/admin/.config/tigervnc \
    && openssl req -x509 -nodes -newkey rsa:2048 -keyout /etc/skel/admin/.vnc/self.pem -out /etc/skel/admin/.vnc/self.pem -days 3650 -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost" \
    && chown -R admin:admin /etc/skel/admin/.vnc /etc/skel/admin/.config/tigervnc

# Provide the XFCE autostart entry that disables the X server built-in
# screen saver (runs after the session is fully initialised).
COPY --chown=admin:admin config/autostart/disable-x11-screensaver.desktop /etc/skel/admin/.config/autostart/disable-x11-screensaver.desktop
COPY config/disable-x11-screensaver.sh /usr/local/bin/disable-x11-screensaver.sh

# Provide an xstartup script in both traditional and XDG locations
COPY --chown=admin:admin config/xstartup /etc/skel/admin/.vnc/xstartup
RUN chmod +x /etc/skel/admin/.vnc/xstartup \
    && chmod +x /usr/local/bin/disable-x11-screensaver.sh \
    && ln -sf /home/admin/.vnc/xstartup /etc/skel/admin/.config/tigervnc/xstartup

# Create Desktop icons and autostart for the applications in the skeleton directory
RUN mkdir -p /etc/skel/admin/Desktop /etc/skel/admin/.config/autostart \
    && cp /usr/share/applications/google-chrome.desktop /etc/skel/admin/Desktop/ \
    && cp /usr/share/applications/signal-desktop.desktop /etc/skel/admin/Desktop/ \
    && cp /usr/share/applications/code.desktop /etc/skel/admin/Desktop/ \
    && cp /usr/share/applications/guake.desktop /etc/skel/admin/.config/autostart/ \
    && chmod +x /etc/skel/admin/Desktop/*.desktop \
    && chmod +x /etc/skel/admin/.config/autostart/*.desktop \
    && chmod +x /etc/skel/admin/.config/autostart/disable-x11-screensaver.desktop \
    && chown -R admin:admin /etc/skel/admin/Desktop /etc/skel/admin/.config/autostart

# Create required X11 session files in the skeleton directory
RUN touch /etc/skel/admin/.Xauthority /etc/skel/admin/.Xresources \
    && chown admin:admin /etc/skel/admin/.Xauthority /etc/skel/admin/.Xresources

# Switch to the non-root user
USER root

# Copy in the entrypoint script and reset script
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY config/reset-xfce4 /usr/local/bin/reset-xfce4
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/reset-xfce4

# Copy the desktop orchestrator, audio proxy, and custom xflock4
COPY config/start-desktop.sh /usr/local/bin/start-desktop.sh
COPY config/audio-proxy.sh /usr/local/bin/audio-proxy.sh
COPY config/xflock4 /usr/local/bin/xflock4
RUN chmod +x /usr/local/bin/start-desktop.sh /usr/local/bin/audio-proxy.sh /usr/local/bin/xflock4

# Expose noVNC and audio WebSocket ports
EXPOSE 6901
EXPOSE 6902

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/usr/local/bin/start-desktop.sh"]

