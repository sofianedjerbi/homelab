#!/bin/bash
set -euo pipefail

HETZNER_IP="$1"
TALOS_VERSION="$2"
IMAGE_URL="https://github.com/siderolabs/talos/releases/download/${TALOS_VERSION}/metal-amd64.raw.zst"

echo "Installing Talos ${TALOS_VERSION}"
echo "Image URL: $IMAGE_URL"

ssh-keygen -R "$HETZNER_IP" 2>/dev/null || true

ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@"$HETZNER_IP" << EOF
apt update && apt install -y zstd wget

if [ ! -f metal-amd64.raw.zst ]; then
  wget ${IMAGE_URL}
fi

if [ ! -f metal-amd64.raw ]; then
  zstd -d metal-amd64.raw.zst
fi

dd if=metal-amd64.raw of=/dev/sda bs=4M status=progress && sync
echo b > /proc/sysrq-trigger
EOF
