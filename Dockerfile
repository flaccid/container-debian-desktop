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

# Create a non-root user (UID 1000)
ARG USERNAME=admin
ARG USER_UID=1000
ARG USER_GID=1000

RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m -s /bin/bash $USERNAME \
    && echo "$USERNAME ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME

# Create a default index.html to redirect to vnc_auto.html
RUN echo '<meta http-equiv="refresh" content="0; url=vnc_auto.html?resize=remote">' > /usr/share/novnc/index.html

USER $USERNAME
WORKDIR /home/$USERNAME

# Setup VNC configuration and generate a self-signed certificate for HTTPS noVNC
RUN mkdir -p /home/$USERNAME/.vnc \
    && openssl req -x509 -nodes -newkey rsa:2048 -keyout /home/$USERNAME/.vnc/self.pem -out /home/$USERNAME/.vnc/self.pem -days 3650 -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost"

RUN mkdir -p /home/$USERNAME/.config/tigervnc

RUN touch /home/$USERNAME/.Xauthority

# Configure XFCE: single panel (no Panel 2), Adwaita-dark theme
RUN mkdir -p /home/$USERNAME/.config/xfce4/xfconf/xfce-perchannel-xml \
    && { \
         echo '<?xml version="1.0" encoding="UTF-8"?>'; \
         echo ''; \
         echo '<channel name="xfce4-panel" version="1.0">'; \
         echo '  <property name="configver" type="int" value="2"/>'; \
         echo '  <property name="panels" type="array">'; \
         echo '    <value type="int" value="1"/>'; \
         echo '    <property name="panel-0" type="array">'; \
         echo '      <property name="position" type="string" value="p=6;x=0;y=0"/>'; \
         echo '      <property name="length" type="uint" value="100"/>'; \
         echo '      <property name="position-locked" type="bool" value="true"/>'; \
         echo '      <property name="size" type="uint" value="30"/>'; \
         echo '      <property name="plugin-ids" type="array">'; \
         echo '        <value type="int" value="1"/>'; \
         echo '        <value type="int" value="2"/>'; \
         echo '        <value type="int" value="3"/>'; \
         echo '        <value type="int" value="4"/>'; \
         echo '        <value type="int" value="5"/>'; \
         echo '        <value type="int" value="6"/>'; \
         echo '      </property>'; \
         echo '    </property>'; \
         echo '    <property name="plugin-1" type="string" value="applicationsmenu"/>'; \
         echo '    <property name="plugin-2" type="string" value="tasklist"/>'; \
         echo '    <property name="plugin-3" type="string" value="separator"/>'; \
         echo '    <property name="plugin-4" type="string" value="pager"/>'; \
         echo '    <property name="plugin-5" type="string" value="systray"/>'; \
         echo '    <property name="plugin-6" type="string" value="clock"/>'; \
         echo '  </property>'; \
         echo '</channel>'; \
       } > /home/$USERNAME/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml \
    && { \
         echo '<?xml version="1.0" encoding="UTF-8"?>'; \
         echo ''; \
         echo '<channel name="xsettings" version="1.0">'; \
         echo '  <property name="Net" type="empty">'; \
         echo '    <property name="ThemeName" type="string" value="Adwaita-dark"/>'; \
         echo '    <property name="IconThemeName" type="string" value="Adwaita"/>'; \
         echo '  </property>'; \
         echo '</channel>'; \
       } > /home/$USERNAME/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml

# Provide a simple xstartup script to launch XFCE
RUN echo '#!/bin/bash\n\n\
xrdb $HOME/.Xresources\n\
startxfce4 &\n\
' > /home/$USERNAME/.vnc/xstartup && chmod +x /home/$USERNAME/.vnc/xstartup

# Expose the noVNC port
EXPOSE 6901

CMD ["sh", "-c", "vncserver :1 -geometry 1920x1080 -depth 24 -localhost no -SecurityTypes None --I-KNOW-THIS-IS-INSECURE && websockify --web /usr/share/novnc --cert /home/admin/.vnc/self.pem 6901 localhost:5901"]
