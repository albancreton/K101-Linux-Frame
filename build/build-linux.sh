#!/usr/bin/env bash
# Build the kernel + DTB for the K101 frame inside the dashframe-build container.
# Output: out/linux/arch/arm/boot/zImage, out/linux/arch/arm/boot/dts/allwinner/sun8i-a33-k101-frame.dtb
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
docker build -q -t dashframe-build "$ROOT/build" >/dev/null

docker run --rm -u "$(id -u):$(id -g)" -v "$ROOT:/work" dashframe-build bash -euc '
    cd src/linux
    # Re-apply our patches on a clean tree each time.
    git checkout -q -- . && git clean -qfd arch/arm/boot/dts
    for p in ../../board/linux/patches/*.patch; do git apply "$p"; done
    cp ../../board/dts/sun8i-a33-k101-frame.dts arch/arm/boot/dts/allwinner/
    echo "dtb-\$(CONFIG_MACH_SUN8I) += sun8i-a33-k101-frame.dtb" >> arch/arm/boot/dts/allwinner/Makefile

    O=../../out/linux
    make O=$O sunxi_defconfig >/dev/null
    scripts/kconfig/merge_config.sh -O $O -m $O/.config ../../board/linux/k101.config >/dev/null
    sed -i "s|^CONFIG_EXTRA_FIRMWARE_DIR=.*||" $O/.config
    echo "CONFIG_EXTRA_FIRMWARE_DIR=\"/work/hw/firmware\"" >> $O/.config
    make O=$O olddefconfig >/dev/null

    # Every fragment option must have survived olddefconfig.
    missing=0
    while IFS= read -r line; do
        case "$line" in CONFIG_*) grep -qxF "$line" $O/.config || { echo "not applied: $line"; missing=1; } ;; esac
    done < ../../board/linux/k101.config
    [ $missing = 0 ]

    make O=$O -j"$(nproc)" zImage dtbs modules
    make O=$O INSTALL_MOD_PATH=$O/modules-install modules_install >/dev/null
'
ls -la "$ROOT/out/linux/arch/arm/boot/zImage" "$ROOT/out/linux/arch/arm/boot/dts/allwinner/sun8i-a33-k101-frame.dtb"
