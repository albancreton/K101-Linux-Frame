#!/usr/bin/env bash
# Build the Debian trixie armhf root filesystem as an ext4 image.
# Needs qemu-user-static on the host (binfmt for armhf).
# Output: out/rootfs.img (grown to the full partition on first boot)
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
[ -e /proc/sys/fs/binfmt_misc/qemu-arm ] || { echo "install qemu-user-static first" >&2; exit 1; }
[ -d "$ROOT/out/linux/modules-install/lib/modules" ] || { echo "run build-linux.sh first" >&2; exit 1; }
docker build -q -t dashframe-build "$ROOT/build" >/dev/null

PACKAGES=(
	# base system
	systemd-sysv udev dbus kmod iproute2 iputils-ping procps psmisc less nano
	sudo ca-certificates curl e2fsprogs dosfstools systemd-timesyncd
	# network: Wi-Fi (RTL8188FU firmware), DNS, mDNS, SSH
	iwd firmware-realtek wireless-regdb systemd-resolved avahi-daemon libnss-mdns openssh-server
	# kiosk: Wayland compositor, browser, GPU (Mesa lima), fonts
	cage cog chromium mesa-libgallium libgl1-mesa-dri libegl1 libgles2
	fontconfig fonts-dejavu-core fonts-liberation2
	# tools: output rotation, screenshots, input debugging
	wlr-randr grim libinput-tools evtest netcat-openbsd
	# remote access (pkgs.tailscale.com)
	tailscale
)
pkgs=$(printf '%s,' "${PACKAGES[@]}" | sed 's/,$//')
# root's authorized_keys: the passphrase-less dev key used by tools/frame-ssh
# (created on first build) plus your own ~/.ssh/id_*.pub.
mkdir -p "$ROOT/secrets"
[ -f "$ROOT/secrets/dashframe_ed25519" ] ||
	ssh-keygen -q -t ed25519 -N "" -C dashframe-dev -f "$ROOT/secrets/dashframe_ed25519"
pubkeys=$(cat "$ROOT/secrets/dashframe_ed25519.pub" "$HOME"/.ssh/id_*.pub 2>/dev/null || true)
# --privileged: mmdebstrap needs namespaces and mounts; without them it
# silently falls back to a mode that loses file ownership.
docker run --rm --privileged -v "$ROOT:/work" -e SSH_PUBKEY="$pubkeys" \
	dashframe-build bash -euc '
    # apt resolves signed-by on the build side too, so install the key on both sides
    KEY=tailscale-archive-keyring.gpg
    cp /work/board/rootfs/keys/$KEY /usr/share/keyrings/
    mmdebstrap --arch=armhf --variant=minbase \
        --components="main contrib non-free non-free-firmware" \
        --include="'"$pkgs"'" \
        --setup-hook="mkdir -p \"\$1/usr/share/keyrings\"" \
        --setup-hook="copy-in /usr/share/keyrings/$KEY /usr/share/keyrings/" \
        --customize-hook="sync-in /work/board/rootfs/overlay /" \
        --customize-hook="mkdir -p \"\$1/usr/lib/modules\" \"\$1/usr/lib/firmware/silead\"" \
        --customize-hook="sync-in /work/out/linux/modules-install/lib/modules /usr/lib/modules" \
        --customize-hook="sync-in /work/hw/firmware/silead /usr/lib/firmware/silead" \
        --customize-hook="/work/board/rootfs/customize.sh \"\$1\"" \
        trixie /tmp/rootfs \
        "deb http://deb.debian.org/debian trixie main contrib non-free non-free-firmware" \
        "deb http://deb.debian.org/debian trixie-updates main contrib non-free non-free-firmware" \
        "deb http://security.debian.org/debian-security trixie-security main contrib non-free non-free-firmware" \
        "deb [signed-by=/usr/share/keyrings/$KEY] https://pkgs.tailscale.com/stable/debian trixie main"

    # Generous first image; x-systemd.growfs fills the partition at boot.
    rm -f /work/out/rootfs.img /work/out/rootfs.tar
    mke2fs -q -t ext4 -L dashframe-root -d /tmp/rootfs /work/out/rootfs.img 3G
    chown '"$(id -u):$(id -g)"' /work/out/rootfs.img
'
ls -la "$ROOT/out/rootfs.img"
