#!/bin/sh
# Generate architecture-specific package lists for live-build.
# Usage: gen-arch-packages.sh <arch> <config-package-lists-dir>
set -eu

ARCH="${1:?usage: gen-arch-packages.sh <arch> <lists-dir>}"
LISTS_DIR="${2:?usage: gen-arch-packages.sh <arch> <lists-dir>}"

mkdir -p "${LISTS_DIR}"

case "${ARCH}" in
    amd64)
        printf '%s\n' "linux-image-amd64" > "${LISTS_DIR}/kernel-${ARCH}.list.chroot"
        cat > "${LISTS_DIR}/bootloaders-${ARCH}.list.chroot" << 'EOF'
grub-pc-bin
grub-efi-amd64-bin
grub-efi-amd64-signed
shim-signed
shim-signed-common
mokutil
EOF
        ;;
    arm64)
        printf '%s\n' "linux-image-arm64" > "${LISTS_DIR}/kernel-${ARCH}.list.chroot"
        cat > "${LISTS_DIR}/bootloaders-${ARCH}.list.chroot" << 'EOF'
grub-efi-arm64-bin
grub-efi-arm64-signed
grub-efi-arm64-unsigned
grub2-common
mokutil
mtools
shim-helpers-arm64-signed
shim-signed
shim-signed-common
shim-unsigned
EOF
        ;;
    *)
        echo "error: unsupported architecture '${ARCH}'" >&2
        exit 1
        ;;
esac

echo "Generated kernel-${ARCH}.list.chroot and bootloaders-${ARCH}.list.chroot in ${LISTS_DIR}"
