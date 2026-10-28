#!/usr/bin/env bash
# Build the bring-up initramfs (Debian busybox-static:armhf + board/initramfs/init).
# Output: out/initramfs.cpio.gz
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
docker build -q -t dashframe-build "$ROOT/build" >/dev/null

docker run --rm -v "$ROOT:/work" dashframe-build bash -euc '
    dpkg --add-architecture armhf
    apt-get update -qq
    cd /tmp && apt-get download -qq busybox-static:armhf
    rm -rf rootfs && mkdir -p rootfs/bin rootfs/dev
    dpkg-deb -x busybox-static_*_armhf.deb deb
    cp deb/usr/bin/busybox rootfs/bin/busybox
    ln -s busybox rootfs/bin/sh   # /init is a #!/bin/sh script
    install -m 755 /work/board/initramfs/init rootfs/init
    cp -r /work/board/initramfs/files/. rootfs/
    mknod -m 600 rootfs/dev/console c 5 1
    (cd rootfs && find . | cpio -o -H newc --quiet | gzip -9) > /work/out/initramfs.cpio.gz
    chown '"$(id -u):$(id -g)"' /work/out/initramfs.cpio.gz
    file rootfs/bin/busybox 2>/dev/null || true
'
ls -la "$ROOT/out/initramfs.cpio.gz"
