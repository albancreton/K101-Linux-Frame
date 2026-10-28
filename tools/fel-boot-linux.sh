#!/usr/bin/env bash
# Boot the freshly built kernel + DTB + initramfs over FEL and record the USB
# console (kernel log + shell) from the moment it appears, to out/console.log.
#
#   tools/fel-boot-linux.sh [extra bootargs]
#
# U-Boot arms the 16 s SoC watchdog before booting; only the initramfs feeds it,
# so a kernel that never reaches userspace resets back to FEL on its own.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
OUT=$ROOT/out
K=$OUT/linux/arch/arm/boot

initrd_size=$(printf %x "$(stat -c%s "$OUT/initramfs.cpio.gz")")
cat > "$OUT/boot-initramfs.cmd" <<EOF
wdt dev watchdog@1c20ca0
wdt start 16000
setenv bootargs console=ttyGS0,115200 console=tty0 loglevel=8 g_cdc.idVendor=0x1f3a g_cdc.idProduct=0x1011 g_cdc.host_addr=02:da:5f:00:00:01 g_cdc.dev_addr=02:da:5f:00:00:02 fbcon=rotate:1 $*
bootz 0x42000000 0x43400000:$initrd_size 0x43000000
EOF

"$ROOT/tools/fel-uboot.sh" "$OUT/boot-initramfs.cmd" \
	0x42000000="$K/zImage" \
	0x43000000="$K/dts/allwinner/sun8i-a33-k101-frame.dtb" \
	0x43400000="$OUT/initramfs.cpio.gz" | grep -v '%'

# U-Boot's own ACM console goes away when the kernel starts; wait for the kernel's.
for _ in $(seq 1 30); do lsusb -d 1f3a:1011 >/dev/null && [ -e /dev/ttyACM0 ] && break; sleep 0.5; done
if ! lsusb -d 1f3a:1011 >/dev/null; then echo "kernel gadget did not appear" >&2; exit 1; fi

# Record until the console goes away or 20 s of silence (shell idle).
python3 - "$OUT/console.log" <<'EOF'
import os, select, sys, termios
fd = os.open("/dev/ttyACM0", os.O_RDWR | os.O_NOCTTY)
a = termios.tcgetattr(fd); a[0] = a[1] = a[3] = 0; termios.tcsetattr(fd, termios.TCSANOW, a)
os.write(fd, b"\n")
with open(sys.argv[1], "wb") as log:
    while True:
        r, _, _ = select.select([fd], [], [], 20)
        if not r:
            break
        try:
            data = os.read(fd, 4096)
        except OSError:
            print("[console disconnected]"); break
        if not data:
            break
        log.write(data); log.flush()
EOF
echo "console log: $OUT/console.log ($(wc -l < "$OUT/console.log") lines)"
