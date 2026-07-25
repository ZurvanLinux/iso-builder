#!/bin/bash
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ISO="${1:-${SCRIPT_DIR}/out/live-image-arm64.hybrid.iso}"

if [ ! -f "$ISO" ]; then
    echo "error: ISO not found at '$ISO'" >&2
    echo "usage: $0 [path/to/live-image-arm64.hybrid.iso]" >&2
    exit 1
fi

VARS_FILE="/tmp/edk2-arm-vars.fd"
rm -f "$VARS_FILE"
cp /opt/homebrew/share/qemu/edk2-arm-vars.fd "$VARS_FILE"

sudo qemu-system-aarch64 \
  -accel hvf \
  -cpu host \
  -smp 4 \
  -m 4G \
  -M virt,highmem=on \
  -drive if=pflash,format=raw,readonly=on,file=/opt/homebrew/share/qemu/edk2-aarch64-code.fd \
  -drive if=pflash,format=raw,file="$VARS_FILE" \
  -device virtio-gpu-pci,xres=1920,yres=1080 \
  -device qemu-xhci,id=xhci \
  -device usb-kbd,bus=xhci.0 \
  -device usb-tablet,bus=xhci.0 \
  -audiodev coreaudio,id=audio0 \
  -device usb-audio,bus=xhci.0,audiodev=audio0 \
  -netdev vmnet-host,id=net0 \
  -device virtio-net-pci,netdev=net0 \
  -drive file="$ISO",if=virtio,format=raw,readonly=on \
  -display cocoa,zoom-to-fit=on
