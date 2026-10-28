#!/usr/bin/env bash
# Push the freshly built kernel, DTB and modules to the running frame over SSH
# (USB link by default; FRAME=host for Wi-Fi/Tailscale), then reboot it.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
K=$ROOT/out/linux
SSH=$ROOT/tools/frame-ssh
rel=$(cat "$K/include/config/kernel.release")

"$SSH" 'cat > /boot/firmware/zImage.new' < "$K/arch/arm/boot/zImage"
"$SSH" 'cat > /boot/firmware/sun8i-a33-k101-frame.dtb.new' < "$K/arch/arm/boot/dts/allwinner/sun8i-a33-k101-frame.dtb"
tar -C "$K/modules-install/lib/modules" -c "$rel" | "$SSH" "rm -rf /usr/lib/modules/$rel && tar -x -C /usr/lib/modules && depmod -a $rel"
"$SSH" 'cd /boot/firmware && mv zImage.new zImage && mv sun8i-a33-k101-frame.dtb.new sun8i-a33-k101-frame.dtb && sync'
echo "kernel $rel installed"
[ "${1:-}" = --no-reboot ] || "$SSH" 'systemctl reboot' || true
