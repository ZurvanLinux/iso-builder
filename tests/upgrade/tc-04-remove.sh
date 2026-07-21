#!/bin/sh
set -e
CHROOT="${CHROOT:-/tmp/zurvan-upgrade-chroot}"
DEB="$(ls packages/zurvan-base-files_*.deb | head -n1)"
[ -n "$DEB" ]

chroot "$CHROOT" dpkg -r zurvan-base-files >/dev/null 2>&1

grep -qi "debian" "$CHROOT/etc/os-release"
chroot "$CHROOT" dpkg-divert --list /etc/os-release | grep -q "distrib" || true
chroot "$CHROOT" dpkg -S /etc/os-release >/dev/null 2>&1 || true
[ ! -f "$CHROOT/etc/os-release.distrib" ]
