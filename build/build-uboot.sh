#!/usr/bin/env bash
# Build U-Boot for the K101 frame inside the dashframe-build container.
# Output: out/u-boot/u-boot-sunxi-with-spl.bin
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
docker build -q -t dashframe-build "$ROOT/build" >/dev/null

docker run --rm -u "$(id -u):$(id -g)" -v "$ROOT:/work" dashframe-build bash -euc '
    cd src/u-boot
    cp ../../board/dts/sun8i-a33-k101-frame.dts arch/arm/dts/
    cp ../../board/u-boot/k101_frame_defconfig configs/
    grep -q sun8i-a33-k101-frame.dtb arch/arm/dts/Makefile ||
        sed -i "s/^\(dtb-\$(CONFIG_MACH_SUN8I_A33) += \\\\\)$/\1\n\tsun8i-a33-k101-frame.dtb \\\\/" arch/arm/dts/Makefile
    make O=../../out/u-boot k101_frame_defconfig
    make O=../../out/u-boot -j"$(nproc)"
'
ls -la "$ROOT/out/u-boot/u-boot-sunxi-with-spl.bin"
