#!/bin/sh
set -e
CHROOT="${CHROOT:-/tmp/zurvan-upgrade-chroot}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=tests/upgrade/chroot-setup.sh
. "$SCRIPT_DIR/chroot-setup.sh"

DEB="$(find packages -maxdepth 1 -name 'zurvan-base-files_*.deb' -print -quit)"
[ -n "$DEB" ]

chroot "$CHROOT" dpkg -r zurvan-base-files >/dev/null 2>&1

grep -q '^NAME="Debian"' "$CHROOT/etc/os-release"
chroot "$CHROOT" dpkg-divert --list /etc/os-release | grep -q "distrib" || true
chroot "$CHROOT" dpkg -S /etc/os-release >/dev/null 2>&1 || true
[ ! -f "$CHROOT/etc/os-release.distrib" ]

