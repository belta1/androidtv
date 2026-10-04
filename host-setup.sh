#!/bin/bash
# One-time host preparation (Ubuntu/Debian x86_64). Run with sudo.
#  - kernel binder module for redroid
#  - APK folder
#  - `magictv` command + "Magic TV" menu icon for every user on the machine
set -euo pipefail

APK_OWNER="${SUDO_USER:-belta1}"
APK_DIR=/home/belta1/docker_compose/config/magictv

# --- redroid kernel support -------------------------------------------------
apt-get update
apt-get install -y "linux-modules-extra-$(uname -r)" || \
  echo "linux-modules-extra not available; assuming binder is built into the kernel"
modprobe binder_linux devices="binder,hwbinder,vndbinder"
echo "binder_linux" > /etc/modules-load.d/redroid.conf
echo 'options binder_linux devices="binder,hwbinder,vndbinder"' > /etc/modprobe.d/redroid.conf

# --- APK folder -------------------------------------------------------------
mkdir -p "$APK_DIR"
chown "$APK_OWNER:" "$APK_DIR"

# --- window settings (shared by all users, editable by root) ----------------
if [ ! -f /etc/magictv.conf ]; then
  cat > /etc/magictv.conf <<'EOF'
# Magic TV window settings for every user (docker --env-file format)
MAX_SIZE=1920
FPS=60
VIDEO_BITRATE=8M
FULLSCREEN=false
WINDOW_WIDTH=1280
WINDOW_HEIGHT=720
# APP_PACKAGE=
EOF
fi

# --- root helper: opens a window container in the calling user's session ----
mkdir -p /usr/local/lib/magictv
cat > /usr/local/lib/magictv/run <<'EOF'
#!/bin/bash
# Started via sudo by /usr/local/bin/magictv. Runs the viewer container as the
# calling user (SUDO_UID), with access only to that user's desktop session.
set -euo pipefail

IMAGE=ghcr.io/belta1/androidtv-viewer:latest
uid="${SUDO_UID:?run this through the magictv command}"
gid="${SUDO_GID:?}"
name="magictv-window-$uid"

# Only accept well-formed display names from the (kept) user environment
wl="${WAYLAND_DISPLAY:-wayland-0}"; [[ "$wl" =~ ^wayland-[0-9]+$ ]] || wl=wayland-0
x11="${DISPLAY:-:0}";              [[ "$x11" =~ ^:[0-9]+(\.[0-9]+)?$ ]] || x11=:0

# Already open for this user: nothing to do
if [ -n "$(docker ps -q -f "name=^${name}$")" ]; then
  echo "Magic TV is already open"
  exit 0
fi
docker rm -f "$name" >/dev/null 2>&1 || true

extra=()
[ -e /dev/dri ] && extra+=(--device /dev/dri --group-add video)
render_gid="$(getent group render | cut -d: -f3 || true)"
[ -n "$render_gid" ] && extra+=(--group-add "$render_gid")
[ -d /tmp/.X11-unix ] && extra+=(-v /tmp/.X11-unix:/tmp/.X11-unix:ro)

exec docker run --rm --name "$name" --pull never \
  --network magictv \
  --user "$uid:$gid" \
  --memory 384m \
  --env-file /etc/magictv.conf \
  -e MODE=window \
  -e ANDROID_HOST=android:5555 \
  -e XDG_RUNTIME_DIR="/run/user/$uid" \
  -e WAYLAND_DISPLAY="$wl" \
  -e DISPLAY="$x11" \
  -v "/run/user/$uid:/run/user/$uid" \
  "${extra[@]}" \
  "$IMAGE"
EOF
chmod 755 /usr/local/lib/magictv/run
chown -R root:root /usr/local/lib/magictv

# --- user command -----------------------------------------------------------
cat > /usr/local/bin/magictv <<'EOF'
#!/bin/sh
# Opens Magic TV in a window on the current desktop session.
sudo -n /usr/local/lib/magictv/run || {
  command -v notify-send >/dev/null && \
    notify-send -i video-display "Magic TV" "No se pudo abrir. Ejecuta 'magictv' en una terminal para ver el error."
  exit 1
}
EOF
chmod 755 /usr/local/bin/magictv

# Every user may run the helper as root without password, with no arguments
cat > /etc/sudoers.d/magictv <<'EOF'
Defaults!/usr/local/lib/magictv/run env_keep += "WAYLAND_DISPLAY DISPLAY"
ALL ALL=(root) NOPASSWD: /usr/local/lib/magictv/run ""
EOF
chmod 440 /etc/sudoers.d/magictv
visudo -cf /etc/sudoers.d/magictv

# --- menu icon for all users ------------------------------------------------
cat > /usr/share/applications/magictv.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=Magic TV
Comment=Abrir Magic TV (Android en contenedor)
Exec=magictv
Icon=video-display
Terminal=false
Categories=AudioVideo;Video;TV;
StartupWMClass=magictv
EOF
update-desktop-database /usr/share/applications 2>/dev/null || true

grep -q binder /proc/filesystems && echo "OK: binder available."
echo "Copy the Magic TV .apk to $APK_DIR, deploy the Portainer stack,"
echo "then any user can open it from the menu (Magic TV) or by running: magictv"
