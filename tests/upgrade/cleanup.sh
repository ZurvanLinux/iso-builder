#!/bin/sh
set -e
CHROOT="${CHROOT:-/tmp/zurvan-upgrade-chroot}"
if [ -d "$CHROOT" ]; then
    umount -R "$CHROOT" >/dev/null 2>&1 || true
    rm -rf "$CHROOT"
fi
