#!/bin/zsh

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
  -device usb-ehci,id=usb \
  -device usb-kbd \
  -device usb-tablet \
  -audiodev coreaudio,id=audio0 \
  -device virtio-sound-pci,audiodev=audio0 \
  -netdev vmnet-shared,id=net0 \
  -device virtio-net-pci,netdev=net0 \
  -drive file=/Users/mohammad/Downloads/zurvan-live-iso-arm64/live-image-arm64.hybrid.iso,if=virtio,format=raw,readonly=on \
  -display cocoa,zoom-to-fit=on
