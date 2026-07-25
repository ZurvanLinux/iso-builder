#!/usr/bin/env bash
set -euo pipefail

# Source centralized build configuration (single source of truth).
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=../build.env
. "${SCRIPT_DIR}/build.env"

VM_NAME="zurvan-builder"
GUEST_DIR="/home/ubuntu/iso-builder"

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
    STATE=$(multipass list --format json | jq -r --arg name "${VM_NAME}" '.list[] | select(.name == $name) | .state' 2>/dev/null || echo "unknown")
    if [ "${STATE}" != "Running" ]; then
        echo "Starting VM '${VM_NAME}'..."
        multipass start "${VM_NAME}"
    fi
fi

echo "Waiting for VM SSH to become ready (max 3 minutes)..."
TIMEOUT=180
ELAPSED=0
while ! multipass exec "${VM_NAME}" -- true 2>/dev/null; do
    sleep 2
    ELAPSED=$((ELAPSED + 2))
    if [ "$ELAPSED" -ge "$TIMEOUT" ]; then
        echo "error: VM SSH not ready after ${TIMEOUT}s" >&2
        exit 1
    fi
done

echo "=== 3. Installing Docker in VM == "
multipass exec "${VM_NAME}" -- bash -c "
    sudo apt-get update -qq && \
    sudo apt-get install -y -qq docker.io && \
    sudo usermod -aG docker ubuntu || true
"

echo "=== 4. Transferring local working tree to VM == "
multipass exec "${VM_NAME}" -- bash -c "
    sudo mv ${GUEST_DIR} ${GUEST_DIR}.old.\$(date +%s) 2>/dev/null || true
    mkdir -p ${GUEST_DIR}
"

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
    --exclude='zurvan-config' \
    -C "${SCRIPT_DIR}" .

echo "Transferring tarball to VM..."
multipass transfer "${TARBALL}" "${VM_NAME}:/tmp/zurvan-iso-builder.tar.gz"

echo "Extracting in VM..."
multipass exec "${VM_NAME}" -- bash -c "cd ${GUEST_DIR} && tar xzf /tmp/zurvan-iso-builder.tar.gz && rm -f /tmp/zurvan-iso-builder.tar.gz"
rm -f "${TARBALL}"

echo "=== 4b. Cloning zurvan-config in VM == "
multipass exec "${VM_NAME}" -- bash -c "
    cd ${GUEST_DIR} && \
    git clone 'https://github.com/${ZURVAN_CONFIG_REPO}' zurvan-config 2>/dev/null || true && \
    (cd zurvan-config && git checkout '${ZURVAN_CONFIG_REF}') || true
"

echo "=== 5. Running Debian ${DEBIAN_CODENAME} container build (${ARCH}) == "
if [ "${ARCH}" = "amd64" ]; then
    GRUB_PKGS="grub-pc-bin grub-efi-amd64-bin isolinux syslinux syslinux-common"
    CONTAINER_IMAGE="${DEBIAN_IMAGE_AMD64}"
else
    GRUB_PKGS="grub-efi-arm64-bin"
    CONTAINER_IMAGE="${DEBIAN_IMAGE_ARM64}"
fi

multipass exec "${VM_NAME}" -- bash -c "
    cd ${GUEST_DIR} && \
    sudo docker run --rm --platform linux/${ARCH} --privileged -v \$(pwd):/workspace -w /workspace \
        '${CONTAINER_IMAGE}' \
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
            bash scripts/apply-zurvan-config.sh
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
mkdir -p "${SCRIPT_DIR}/scripts/out"
if ! multipass transfer "${VM_NAME}:${GUEST_DIR}/live-image-${ARCH}.hybrid.iso" "${SCRIPT_DIR}/scripts/out/"; then
    echo "error: ISO not found in VM — build may have failed" >&2
    exit 1
fi
multipass transfer "${VM_NAME}:${GUEST_DIR}/lb-build-1.log" "${SCRIPT_DIR}/scripts/" || echo "warning: Log not found in VM" >&2

echo "=== 7. Build complete! Artifacts collected: == "
ls -lah "${SCRIPT_DIR}/scripts/out/" "${SCRIPT_DIR}/scripts/lb-build-"*.log 2>/dev/null || true
echo "Done."
