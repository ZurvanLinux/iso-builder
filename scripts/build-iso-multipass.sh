#!/usr/bin/env bash
set -euo pipefail

VM_NAME="zurvan-builder"
GUEST_DIR="/home/ubuntu/iso-builder"

echo "=== 1. Checking Multipass == "
if ! command -v multipass &> /dev/null; then
    echo "Multipass is not installed. Installing via Homebrew cask..."
    brew install --cask multipass
fi

echo "=== 2. Checking Multipass VM (${VM_NAME}) == "
if ! multipass list --format json | jq -e --arg name "${VM_NAME}" '.list[] | select(.name == $name)' > /dev/null; then
    echo "Launching Multipass VM '${VM_NAME}' (8GB RAM, 80GB Disk, Ubuntu 24.04)..."
    multipass launch --name "${VM_NAME}" --memory 8G --disk 80G 24.04
else
    echo "VM '${VM_NAME}' already exists."
    STATE=$(multipass info "${VM_NAME}" --format json | jq -r ".info.\"${VM_NAME}\".state" 2>/dev/null || echo "unknown")
    if [ "${STATE}" != "Running" ]; then
        echo "Starting VM '${VM_NAME}'..."
        multipass start "${VM_NAME}"
    fi
fi

echo "=== 3. Cleaning up old mounts and installing Docker in VM == "
multipass umount "${VM_NAME}" || true
multipass exec "${VM_NAME}" -- bash -c "
    sudo apt-get update && \
    sudo apt-get install -y docker.io && \
    sudo usermod -aG docker ubuntu || true
"

echo "=== 4. Cloning repo inside VM == "
multipass exec "${VM_NAME}" -- bash -c "
    sudo rm -rf ${GUEST_DIR} && \
    git clone -b main https://github.com/ZurvanLinux/iso-builder.git ${GUEST_DIR}
"

echo "=== 5. Running native ARM64 Debian Trixie container build matching CI workflow == "
multipass exec "${VM_NAME}" -- bash -c "
    cd ${GUEST_DIR} && \
    sudo docker run --rm --platform linux/arm64 --privileged -v \$(pwd):/workspace -w /workspace \
        debian:trixie \
        bash -c '
            set -eux
            export DEBIAN_FRONTEND=noninteractive
            apt-get update -o Acquire::Check-Valid-Until=false -o Acquire::AllowInsecureRepositories=true || true
            apt-get install -y --no-install-recommends --allow-unauthenticated debian-archive-keyring ca-certificates
            apt-get update -o Acquire::Check-Valid-Until=false -o Acquire::AllowInsecureRepositories=true
            apt-get install -y --no-install-recommends --allow-unauthenticated \
                live-build debootstrap \
                squashfs-tools xorriso \
                grub-efi-arm64-bin \
                mtools dosfstools \
                curl jq \
                build-essential \
                dpkg-dev debhelper fakeroot
            printf \"%s\n\" \"linux-image-arm64\" > \"config/package-lists/kernel-arm64.list.chroot\"
            bash auto/config arm64
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
mkdir -p ./out
multipass transfer "${VM_NAME}:${GUEST_DIR}/live-image-arm64.hybrid.iso" ./out/ || echo "ISO not found in VM"
multipass transfer "${VM_NAME}:${GUEST_DIR}/lb-build-1.log" ./ || echo "Log not found in VM"

echo "=== 7. Build complete! Artifacts collected: == "
ls -lah ./out/ ./lb-build-*.log 2>/dev/null || true
echo "Done."
