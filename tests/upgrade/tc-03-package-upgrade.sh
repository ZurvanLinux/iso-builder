#!/bin/sh
set -e
CHROOT="${CHROOT:-/tmp/zurvan-upgrade-chroot}"
DEB="$(ls packages/zurvan-base-files_*.deb | head -n1)"
[ -n "$DEB" ]

DEB_OLD="${DEB%.deb}_1.0-2_all.deb"
cp "$DEB" "$DEB_OLD" 2>/dev/null || true

run_build() {
    dch -v 1.0-2 "Upgrade test" >/dev/null 2>&1 || true
    dpkg-buildpackage -us -uc -b >/dev/null 2>&1
}

run_build || true
DEB_NEW="$(ls packages/zurvan-base-files_1.0-2_all.deb 2>/dev/null || ls packages/zurvan-base-files_*.deb | head -n1)"
[ -n "$DEB_NEW" ]

chroot "$CHROOT" dpkg -i "/workspace/$DEB_NEW" >/dev/null 2>&1

grep -q "Zurvan" "$CHROOT/etc/os-release"
chroot "$CHROOT" dpkg-divert --list /etc/os-release | grep -q "distrib"
find "$CHROOT/etc" -maxdepth 1 -name '*.distrib' | wc -l | grep -q '^0$'
