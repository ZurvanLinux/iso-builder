#!/bin/sh
set -e
CHROOT="${CHROOT:-/tmp/zurvan-upgrade-chroot}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=tests/upgrade/chroot-setup.sh
. "$SCRIPT_DIR/chroot-setup.sh"

DEB="$(find packages -maxdepth 1 -name 'zurvan-base-files_*.deb' -print -quit)"
[ -n "$DEB" ]

chroot "$CHROOT" dpkg -P zurvan-base-files >/dev/null 2>&1

chroot "$CHROOT" dpkg-divert --list /etc/os-release | grep -q "distrib" || true
find "$CHROOT/etc" -maxdepth 1 -name '*.distrib' | wc -l | grep -q '^0$'
