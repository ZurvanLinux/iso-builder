#!/usr/bin/env bash
set -euo pipefail

VM_NAME="zurvan-builder"
GUEST_DIR="/home/ubuntu/iso-builder"
ARCH="${ZURVAN_ARCH:-arm64}"

echo "=== 1. Checking Multipass == "
if ! command -v multipass &> /dev/null; then
    echo "Multipass is not installed. Installing via Homebrew cask..."
    brew install --cask multipass
fi

echo "=== 2. Checking Multipass VM (${VM_NAME}) == "
if multipass list --format json | jq -e --arg name "${VM_NAME}" '.list[] | select(.name == $name)' > /dev/null; then
    echo "VM '${VM_NAME}' exists. Verifying SSH responsiveness..."
    if ! multipass exec "${VM_NAME}" -- true 2>/dev/null; then
        echo "VM is unresponsive. Deleting and recreating..."
        multipass delete --purge "${VM_NAME}" || true
    fi
fi

if ! multipass list --format json | jq -e --arg name "${VM_NAME}" '.list[] | select(.name == $name)' > /dev/null; then
    echo "Launching Multipass VM '${VM_NAME}' (8GB RAM, 80GB Disk, Ubuntu 24.04)..."
    multipass launch --name "${VM_NAME}" --memory 8G --disk 80G 24.04
else
    echo "VM '${VM_NAME}' already exists."
    STATE=$(multipass list --format json | jq -r --arg name "${VM_NAME}" '.[] | select(.name == $name) | .state' 2>/dev/null || echo "unknown")
    if [ "${STATE}" != "Running" ]; then
        echo "Starting VM '${VM_NAME}'..."
        multipass start "${VM_NAME}"
    fi
fi

echo "Waiting for VM SSH to become ready..."
while ! multipass exec "${VM_NAME}" -- true 2>/dev/null; do
    sleep 2
done

echo "=== 3. Installing Docker in VM == "
multipass exec "${VM_NAME}" -- bash -c "
    sudo apt-get update -qq && \
    sudo apt-get install -y -qq docker.io && \
    sudo usermod -aG docker ubuntu || true
"

echo "=== 4. Transferring local working tree to VM == "
# Remove stale build dir and recreate
multipass exec "${VM_NAME}" -- bash -c "
    sudo mv ${GUEST_DIR} ${GUEST_DIR}.old.\$(date +%s) 2>/dev/null || true
    mkdir -p ${GUEST_DIR}
"

# Create a tarball of the local repo (excluding build artifacts) and transfer it
TARBALL="/tmp/zurvan-iso-builder.tar.gz"
echo "Creating local tarball..."
COPYFILE_DISABLE=1 tar czf "${TARBALL}" \
    --exclude='.git' \
    --exclude='chroot' \
    --exclude='binary' \
    --exclude='.build' \
    --exclude='cache' \
    --exclude='*.iso' \
    --exclude='*.log' \
    --exclude='scripts/out' \
    --exclude='scripts/lb-build-*' \
    --exclude='.kilo' \
    --exclude='.DS_Store' \
    -C "$(pwd)" .

echo "Transferring tarball to VM..."
multipass transfer "${TARBALL}" "${VM_NAME}:/tmp/zurvan-iso-builder.tar.gz"

echo "Extracting in VM..."
multipass exec "${VM_NAME}" -- bash -c "cd ${GUEST_DIR} && tar xzf /tmp/zurvan-iso-builder.tar.gz && rm -f /tmp/zurvan-iso-builder.tar.gz"
rm -f "${TARBALL}"

echo "=== 5. Running native Debian Trixie container build (${ARCH}) == "
GRUB_PKGS=""
if [ "${ARCH}" = "amd64" ]; then
    GRUB_PKGS="grub-pc-bin grub-efi-amd64-bin isolinux syslinux syslinux-common"
else
    GRUB_PKGS="grub-efi-arm64-bin"
fi

multipass exec "${VM_NAME}" -- bash -c "
    cd ${GUEST_DIR} && \
    sudo docker run --rm --platform linux/${ARCH} --privileged -v \$(pwd):/workspace -w /workspace \
        debian:trixie \
        bash -c '
            set -eux
            export DEBIAN_FRONTEND=noninteractive
            apt-get update -qq
            apt-get install -y --no-install-recommends \
                live-build debootstrap \
                squashfs-tools xorriso \
                ${GRUB_PKGS} \
                mtools dosfstools \
                curl jq \
                build-essential \
                dpkg-dev debhelper fakeroot
            bash scripts/gen-arch-packages.sh ${ARCH} config/package-lists
            bash auto/config ${ARCH}
            lb clean --purge || true
            attempt=1
            max=3
            while [ \"\$attempt\" -le \"\$max\" ]; do
                lb build 2>&1 | tee \"lb-build-\${attempt}.log\" && break
                if [ \"\$attempt\" -eq \"\$max\" ]; then
                    echo \"::error::lb build failed after \${max} attempts\"
                    exit 1
                fi
                sleep_secs=\$((attempt * 30))
                echo \"lb build attempt \${attempt}/\${max} failed; retrying in \${sleep_secs}s...\"
                sleep \"\$sleep_secs\"
                attempt=\$((attempt + 1))
            done
        '
"

echo "=== 6. Copying build artifacts from VM to host == "
mkdir -p ./scripts/out
multipass transfer "${VM_NAME}:${GUEST_DIR}/live-image-${ARCH}.hybrid.iso" "./scripts/out/" || echo "ISO not found in VM"
multipass transfer "${VM_NAME}:${GUEST_DIR}/lb-build-1.log" "./scripts/" || echo "Log not found in VM"

echo "=== 7. Build complete! Artifacts collected: == "
ls -lah ./scripts/out/ ./scripts/lb-build-*.log 2>/dev/null || true
echo "Done."
