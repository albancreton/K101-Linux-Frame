#!/bin/sh
# mmdebstrap customize hook: runs on the build host with the rootfs at $1.
# Expects SSH_PUBKEY in the environment.
set -eu
R=$1

# The overlay is copied with the build host's modes (umask 002): normalise.
(cd /work/board/rootfs/overlay && find . -mindepth 1 -type d) | while read -r d; do chmod 755 "$R/$d"; done
(cd /work/board/rootfs/overlay && find . -type f ! -perm -u+x) | while read -r f; do chmod 644 "$R/$f"; done
chmod 755 "$R"
# ...and with the build user's uid, which is the kiosk user's on the frame.
(cd /work/board/rootfs/overlay && find . -mindepth 1) | while read -r p; do chown -h root:root "$R/$p"; done

echo LANG=C.UTF-8 > "$R/etc/default/locale"

chroot "$R" useradd -m -s /bin/bash -G video,render,input kiosk

mkdir -p "$R/root/.ssh" "$R/boot/firmware"
echo "$SSH_PUBKEY" > "$R/root/.ssh/authorized_keys"
chmod 700 "$R/root/.ssh"
chmod 600 "$R/root/.ssh/authorized_keys"
# Host keys are generated on the frame at first boot (ssh-host-keys.service).
rm -f "$R"/etc/ssh/ssh_host_*

ln -sf /usr/share/zoneinfo/America/Los_Angeles "$R/etc/localtime"
ln -sf /run/systemd/resolve/stub-resolv.conf "$R/etc/resolv.conf"

chroot "$R" depmod -a "$(ls "$R/usr/lib/modules")"
chroot "$R" systemd-hwdb update
chroot "$R" systemctl enable systemd-networkd systemd-resolved iwd \
	kiosk kiosk-menu.socket kiosk-menu-gesture zram-swap ssh-host-keys tailscaled
chroot "$R" systemctl set-default graphical.target
chroot "$R" apt-get clean

# Wi-Fi credentials: secrets/*.psk (iwd format, kept out of the repo).
if ls /work/secrets/*.psk >/dev/null 2>&1; then
	install -d -m 700 "$R/var/lib/iwd"
	install -m 600 /work/secrets/*.psk "$R/var/lib/iwd/"
fi

# Local settings (dashboard URL...): secrets/dashframe.conf replaces the
# overlay's placeholder when it exists.
if [ -f /work/secrets/dashframe.conf ]; then
	install -m 644 /work/secrets/dashframe.conf "$R/etc/dashframe.conf"
fi
