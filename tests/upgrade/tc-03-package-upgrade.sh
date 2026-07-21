#!/bin/sh
set -e
CHROOT="${CHROOT:-/tmp/zurvan-upgrade-chroot}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/chroot-setup.sh"

DEB="$(ls packages/zurvan-base-files_*.deb | head -n1)"
[ -n "$DEB" ]

chroot "$CHROOT" dpkg -i "/workspace/$DEB" >/dev/null 2>&1

grep -q "Zurvan" "$CHROOT/etc/os-release"
chroot "$CHROOT" dpkg-divert --list /etc/os-release | grep -q "distrib"
find "$CHROOT/etc" -maxdepth 1 -name '*.distrib' | wc -l | grep -q '^0$'
