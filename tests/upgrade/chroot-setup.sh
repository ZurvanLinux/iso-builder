#!/bin/sh
set -e

CHROOT="${CHROOT:-/tmp/zurvan-upgrade-chroot}"
ARCH="${ZURVAN_ARCH:-amd64}"

# Source centralized build configuration.
SCRIPT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=../../build.env
. "${SCRIPT_DIR}/build.env"

if [ ! -d "$CHROOT" ]; then
    mkdir -p "$CHROOT"
    debootstrap --variant=minbase --arch="$ARCH" "${DEBIAN_CODENAME}" "$CHROOT" "${MIRROR_MAIN}/"
    mount -t proc proc "$CHROOT/proc" || true
    mount -t sysfs sysfs "$CHROOT/sys" || true
    mount -o bind /dev "$CHROOT/dev" || true
    chroot "$CHROOT" apt-get update >/dev/null 2>&1 || true
    chroot "$CHROOT" apt-get install -y --no-install-recommends \
        base-files lsb-release plymouth calamares dpkg >/dev/null 2>&1 || true
fi
