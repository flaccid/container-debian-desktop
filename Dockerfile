FROM debian:trixie-slim

# Prevent interactive prompts during apt
ENV DEBIAN_FRONTEND=noninteractive

# Add third-party apt repos (VS Code, Google Chrome, Signal)
RUN apt-get update     && apt-get install -y --no-install-recommends \
        curl \
        gpg \
        apt-transport-https \
    && rm -rf /var/lib/apt/lists/* \
    && install -d /usr/share/keyrings \
    && curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /usr/share/keyrings/microsoft-archive-keyring.gpg \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft-archive-keyring.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list \
    && curl -fsSL https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /usr/share/keyrings/google-chrome-keyring.gpg \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome-keyring.gpg] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list \
    && curl -fsSL https://updates.signal.org/desktop/apt/keys.asc | gpg --dearmor -o /usr/share/keyrings/signal-desktop-keyring.gpg \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/signal-desktop-keyring.gpg] https://updates.signal.org/desktop/apt xenial main" > /etc/apt/sources.list.d/signal-desktop.list

# Install desktop environment, VNC server, noVNC, and other utilities
RUN apt-get update && apt-get install -y --no-install-recommends \
    xfce4 \
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
    gnome-themes-extra \
    code \
    google-chrome-stable \
    signal-desktop \
    && rm -rf /var/lib/apt/lists/*

# Create a non-root user (UID 1000)
ARG USERNAME=admin
ARG USER_UID=1000
ARG USER_GID=1000

RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m -s /bin/bash $USERNAME \
    && echo "$USERNAME ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME

# Create a default index.html to redirect to vnc_auto.html
RUN echo '<meta http-equiv="refresh" content="0; url=vnc_auto.html">' > /usr/share/novnc/index.html

USER $USERNAME
WORKDIR /home/$USERNAME

# Setup VNC configuration and generate a self-signed certificate for HTTPS noVNC
RUN mkdir -p /home/$USERNAME/.vnc \
    && openssl req -x509 -nodes -newkey rsa:2048 -keyout /home/$USERNAME/.vnc/self.pem -out /home/$USERNAME/.vnc/self.pem -days 3650 -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost"

RUN mkdir -p /home/$USERNAME/.config/tigervnc

RUN touch /home/$USERNAME/.Xauthority

# Provide a simple xstartup script to launch XFCE
RUN echo '#!/bin/bash\n\n\
xrdb $HOME/.Xresources\n\
startxfce4 &\n\
' > /home/$USERNAME/.vnc/xstartup && chmod +x /home/$USERNAME/.vnc/xstartup

# Expose the noVNC port
EXPOSE 6901

CMD ["sh", "-c", "vncserver :1 -geometry 1920x1080 -depth 24 -localhost no -SecurityTypes None --I-KNOW-THIS-IS-INSECURE && websockify --web /usr/share/novnc --cert /home/admin/.vnc/self.pem 6901 localhost:5901"]
