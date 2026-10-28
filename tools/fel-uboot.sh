#!/usr/bin/env bash
# Load our U-Boot into the frame over USB FEL and wait for its USB console.
#
#   tools/fel-uboot.sh [script.cmd] [addr=file ...]
#
# The frame must be in FEL (1f3a:efe8): the SD card's boot.scr puts it there on
# every normal boot, and `reset` at the U-Boot prompt goes back to it.
# Optional addr=file pairs are staged in DRAM first; the .cmd script (compiled
# with mkimage) is written last so U-Boot sources it. Without a script, U-Boot
# just moves its console to USB (board/u-boot/fel-console.cmd).
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
OUT=$ROOT/out/u-boot
CMD=${1:-$ROOT/board/u-boot/fel-console.cmd}
shift || true

lsusb -d 1f3a:efe8 >/dev/null || { echo "frame not in FEL mode" >&2; exit 1; }

"$OUT/tools/mkimage" -A arm -T script -C none -n fel -d "$CMD" "$OUT/fel.scr" >/dev/null

args=()
for pair in "$@"; do args+=(write "${pair%%=*}" "${pair#*=}"); done
sunxi-fel -p uboot "$OUT/u-boot-sunxi-with-spl.bin" "${args[@]}" write 0x43100000 "$OUT/fel.scr"

for _ in $(seq 1 20); do [ -e /dev/ttyACM0 ] && break; sleep 1; done
[ -e /dev/ttyACM0 ] && echo "U-Boot console on /dev/ttyACM0 (tools/ubcmd.py)"
