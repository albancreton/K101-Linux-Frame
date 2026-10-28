#!/usr/bin/env bash
# Install dashframe onto the frame's SD card over the USB link.
#
# The frame must be running the bring-up initramfs (tools/fel-boot-linux.sh),
# reachable at 10.42.0.1. Streams, with nc:
#   - U-Boot (SPL) to the raw area at 8 KiB          (skip with --no-uboot)
#   - zImage, DTB and boot.scr to the FAT partition 1
#   - out/rootfs.img to partition 2                  (skip with --no-rootfs)
# Then removes the FEL marker so the next boot runs Linux from the card.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
OUT=$ROOT/out
SH=$ROOT/tools/frame-sh.py
FRAME=10.42.0.1
uboot=1 rootfs=1
for a in "$@"; do
	case $a in
	--no-uboot) uboot=0 ;;
	--no-rootfs) rootfs=0 ;;
	*) echo "unknown option $a" >&2; exit 1 ;;
	esac
done

ping -c1 -W2 $FRAME >/dev/null || { echo "frame not reachable at $FRAME" >&2; exit 1; }

"$OUT/u-boot/tools/mkimage" -A arm -T script -C none -n dashframe \
	-d "$ROOT/board/u-boot/boot.cmd" "$OUT/boot.scr" >/dev/null

# send FILE REMOTE_CMD: run REMOTE_CMD reading stdin from the network.
send() {
	local file=$1 cmd=$2
	# stdin from /dev/null: otherwise busybox nc reads the console, and it
	# exits once the sender closes the connection.
	"$SH" --timeout 5 "rm -f /tmp/recv-done; (nc -l -p 5000 </dev/null | $cmd; echo done > /tmp/recv-done) >/tmp/recv.log 2>&1 &" >/dev/null
	sleep 1
	nc -N $FRAME 5000 < "$file"   # OpenBSD nc: -N closes the socket at EOF
	for _ in $(seq 1 600); do
		"$SH" --timeout 5 'cat /tmp/recv-done 2>/dev/null' | grep -q done && break
		sleep 1
	done
	"$SH" 'cat /tmp/recv.log; sync'
}

if [ $uboot = 1 ]; then
	echo "== U-Boot -> raw area"
	send "$OUT/u-boot/u-boot-sunxi-with-spl.bin" 'dd of=/dev/mmcblk0 bs=1024 seek=8 conv=fsync'
fi

echo "== kernel, DTB, boot.scr -> FAT partition"
tar -C "$OUT" -cf "$OUT/boot-files.tar" \
	--transform 's|.*/||' \
	linux/arch/arm/boot/zImage \
	linux/arch/arm/boot/dts/allwinner/sun8i-a33-k101-frame.dtb \
	boot.scr
"$SH" 'mkdir -p /mnt/boot && mount -t vfat /dev/mmcblk0p1 /mnt/boot && ls /mnt/boot | head -3'
send "$OUT/boot-files.tar" 'tar -x -C /mnt/boot'

if [ $rootfs = 1 ]; then
	echo "== rootfs -> partition 2 ($(du -h --apparent-size "$OUT/rootfs.img" | cut -f1), gzip-compressed on the wire)"
	gzip -1 -c "$OUT/rootfs.img" > "$OUT/rootfs.img.gz"
	send "$OUT/rootfs.img.gz" 'gunzip -c | dd of=/dev/mmcblk0p2 bs=1M conv=fsync'
fi

if ls "$ROOT"/secrets/*.psk >/dev/null 2>&1; then
	echo "== Wi-Fi credentials (secrets/*.psk) -> /var/lib/iwd"
	"$SH" 'mkdir -p /mnt/root && mount -t ext4 /dev/mmcblk0p2 /mnt/root && mkdir -p /mnt/root/var/lib/iwd && chmod 700 /mnt/root/var/lib/iwd'
	tar -C "$ROOT/secrets" -cf "$OUT/psk.tar" --mode=600 --owner=0 --group=0 $(cd "$ROOT/secrets" && ls *.psk)
	send "$OUT/psk.tar" 'tar -x -C /mnt/root/var/lib/iwd'
	rm -f "$OUT/psk.tar"
	"$SH" 'umount /mnt/root'
fi

# Saved from a running frame before a reflash (Tailscale identity, SSH host
# keys, browser data):
#   tools/frame-ssh 'tar -C / -cpf - var/lib/tailscale etc/ssh/ssh_host_* home/kiosk/.local/share/wpe' > secrets/frame-state.tar
if [ $rootfs = 1 ] && [ -f "$ROOT/secrets/frame-state.tar" ]; then
	echo "== saved frame state (secrets/frame-state.tar) -> rootfs"
	"$SH" 'mkdir -p /mnt/root && mount -t ext4 /dev/mmcblk0p2 /mnt/root'
	send "$ROOT/secrets/frame-state.tar" 'tar -x -p -C /mnt/root'
	"$SH" 'umount /mnt/root'
fi

"$SH" 'rm -f /mnt/boot/dashframe-fel; ls -la /mnt/boot/zImage /mnt/boot/boot.scr /mnt/boot/*.dtb; umount /mnt/boot; sync'
echo "installed; reboot the frame (tools/frame-sh.py 'reboot -f') to start from the card"
