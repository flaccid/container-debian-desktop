FROM debian:trixie-slim

# Prevent interactive prompts during apt
ENV DEBIAN_FRONTEND=noninteractive

# Add third-party apt repos (VS Code, Google Chrome, Signal)
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
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/signal-desktop-keyring.gpg] https://updates.signal.org/desktop/apt xenial main" > /etc/apt/sources.list.d/signal-desktop.list

# Install desktop environment, VNC server, noVNC, and other utilities
RUN apt-get update && apt-get install -y --no-install-recommends \
    gosu \
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
    guake \
    code \
    google-chrome-stable \
    signal-desktop \
    && rm -rf /var/lib/apt/lists/*

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

# Create a default index.html that sets noVNC remote resizing before redirecting
RUN echo '<!DOCTYPE html><html><head><meta charset="utf-8"><script>try { localStorage.setItem("noVNC_resize", "remote"); } catch(e) {} window.location.replace("vnc_auto.html");</script></head><body><p>Loading...</p></body></html>' > /usr/share/novnc/index.html

# Download wallpaper
RUN mkdir -p /usr/share/backgrounds && \
    curl -fsSL -o /usr/share/backgrounds/wallpaper.jpg \
    "https://images.unsplash.com/photo-1483982258113-b72862e6cff6?ixlib=rb-4.1.0&q=85&fm=jpg&crop=entropy&cs=srgb&dl=rosie-sun-1L71sPT5XKc-unsplash.jpg"

# Copy pre-configured XFCE settings into the skeleton directory
COPY --chown=admin:admin config/xfce4 /etc/skel/admin/.config/xfce4

# Setup VNC configuration in the skeleton directory
RUN mkdir -p /etc/skel/admin/.vnc \
    && mkdir -p /etc/skel/admin/.config/tigervnc \
    && openssl req -x509 -nodes -newkey rsa:2048 -keyout /etc/skel/admin/.vnc/self.pem -out /etc/skel/admin/.vnc/self.pem -days 3650 -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost" \
    && chown -R admin:admin /etc/skel/admin/.vnc /etc/skel/admin/.config/tigervnc

# Provide an xstartup script in both traditional and XDG locations
COPY --chown=admin:admin config/xstartup /etc/skel/admin/.vnc/xstartup
RUN chmod +x /etc/skel/admin/.vnc/xstartup \
    && ln -sf /home/admin/.vnc/xstartup /etc/skel/admin/.config/tigervnc/xstartup

# Create Desktop icons and autostart for the applications in the skeleton directory
RUN mkdir -p /etc/skel/admin/Desktop /etc/skel/admin/.config/autostart \
    && cp /usr/share/applications/google-chrome.desktop /etc/skel/admin/Desktop/ \
    && cp /usr/share/applications/signal-desktop.desktop /etc/skel/admin/Desktop/ \
    && cp /usr/share/applications/code.desktop /etc/skel/admin/Desktop/ \
    && cp /usr/share/applications/guake.desktop /etc/skel/admin/.config/autostart/ \
    && chmod +x /etc/skel/admin/Desktop/*.desktop \
    && chown -R admin:admin /etc/skel/admin/Desktop /etc/skel/admin/.config/autostart

# Create required X11 session files in the skeleton directory
RUN touch /etc/skel/admin/.Xauthority /etc/skel/admin/.Xresources \
    && chown admin:admin /etc/skel/admin/.Xauthority /etc/skel/admin/.Xresources

# Switch to the non-root user
USER root

# Copy in the entrypoint script
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Expose the noVNC port
EXPOSE 6901

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["sh", "-c", "vncserver :1 -geometry 1920x1080 -depth 24 -localhost no -SecurityTypes None --I-KNOW-THIS-IS-INSECURE && websockify --web /usr/share/novnc --cert /home/admin/.vnc/self.pem 6901 localhost:5901"]
