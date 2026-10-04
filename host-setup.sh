#!/bin/bash
# One-time host preparation for redroid (Ubuntu/Debian x86_64). Run with sudo.
set -euo pipefail

DESKTOP_USER="${SUDO_USER:-belta1}"
USER_HOME="$(getent passwd "$DESKTOP_USER" | cut -d: -f6)"
APK_DIR=/home/belta1/docker_compose/config/magictv

apt-get update
apt-get install -y "linux-modules-extra-$(uname -r)" || \
  echo "linux-modules-extra not available; assuming binder is built into the kernel"

modprobe binder_linux devices="binder,hwbinder,vndbinder"

echo "binder_linux" > /etc/modules-load.d/redroid.conf
echo 'options binder_linux devices="binder,hwbinder,vndbinder"' > /etc/modprobe.d/redroid.conf

mkdir -p "$APK_DIR"
chown "$DESKTOP_USER:" "$APK_DIR"

# The desktop icon talks to Docker, so the user must be in the docker group
usermod -aG docker "$DESKTOP_USER"

# "Magic TV" entry in the applications menu (opens the window)
APPS_DIR="$USER_HOME/.local/share/applications"
sudo -u "$DESKTOP_USER" mkdir -p "$APPS_DIR"
cat > "$APPS_DIR/magictv.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=Magic TV
Comment=Abrir Magic TV (Android en contenedor)
Exec=docker exec magictv-viewer magictv-open
Icon=video-display
Terminal=false
Categories=AudioVideo;Video;TV;
StartupWMClass=magictv
DESKTOP
chown "$DESKTOP_USER:" "$APPS_DIR/magictv.desktop"

grep -q binder /proc/filesystems && echo "OK: binder available. Copy the Magic TV .apk to $APK_DIR"
echo "Portainer stack variables for this host:"
echo "  HOST_UID=$(id -u "$DESKTOP_USER")  HOST_GID=$(id -g "$DESKTOP_USER")  RENDER_GID=$(getent group render | cut -d: -f3)"
echo "Log out and back in once so the docker group and the menu icon take effect."
