#!/bin/bash
# One-time host preparation for redroid (Ubuntu/Debian x86_64). Run as root.
set -euo pipefail

apt-get update
apt-get install -y "linux-modules-extra-$(uname -r)" || \
  echo "linux-modules-extra not available; assuming binder is built into the kernel"

modprobe binder_linux devices="binder,hwbinder,vndbinder"

echo "binder_linux" > /etc/modules-load.d/redroid.conf
echo 'options binder_linux devices="binder,hwbinder,vndbinder"' > /etc/modprobe.d/redroid.conf

mkdir -p /opt/magictv/apks

grep -q binder /proc/filesystems && echo "OK: binder available. Copy the Magic TV .apk to /opt/magictv/apks"
echo "Portainer stack variables for this host:"
echo "  HOST_UID=$(id -u "${SUDO_USER:-1000}" 2>/dev/null || echo 1000)  HOST_GID=$(id -g "${SUDO_USER:-1000}" 2>/dev/null || echo 1000)  RENDER_GID=$(getent group render | cut -d: -f3)"
