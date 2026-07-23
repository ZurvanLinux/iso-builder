#!/bin/sh
set -e
CHROOT="${CHROOT:-/tmp/zurvan-upgrade-chroot}"
ARCH="${ZURVAN_ARCH:-amd64}"

if [ ! -d "$CHROOT" ]; then
    mkdir -p "$CHROOT"
    debootstrap --variant=minbase --arch="$ARCH" trixie "$CHROOT" http://deb.debian.org/debian/
    mount -t proc proc "$CHROOT/proc" || true
    mount -t sysfs sysfs "$CHROOT/sys" || true
    mount -o bind /dev "$CHROOT/dev" || true
    chroot "$CHROOT" apt-get update >/dev/null 2>&1 || true
    chroot "$CHROOT" apt-get install -y --no-install-recommends \
        base-files lsb-release plymouth calamares dpkg >/dev/null 2>&1 || true
fi
