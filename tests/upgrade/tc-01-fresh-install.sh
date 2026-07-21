#!/bin/sh
set -e
CHROOT="${CHROOT:-/tmp/zurvan-upgrade-chroot}"
DEB="$(ls packages/zurvan-base-files_*.deb | head -n1)"
[ -n "$DEB" ]

chroot "$CHROOT" dpkg -i "/workspace/$DEB" >/dev/null 2>&1

. "$CHROOT/etc/os-release"
[ "$NAME" = "Zurvan" ]
[ "$VERSION_CODENAME" = "akaran" ]

grep -q "Zurvan" "$CHROOT/etc/lsb-release"
[ "$(chroot "$CHROOT" hostname)" = "zurvan" ]

chroot "$CHROOT" dpkg-divert --list /etc/os-release | grep -q "distrib"
chroot "$CHROOT" dpkg -S /etc/os-release | grep -q "zurvan-base-files"
