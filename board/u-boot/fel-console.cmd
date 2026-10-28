# FEL script: optionally install a new SD boot.scr (staged by the host at
# 0x43200000, size in ${new_bootscr_size}), then move the console to USB ACM
# (/dev/ttyACM0 on the host) and fall through to the U-Boot prompt.
if test -n "${new_bootscr_size}"; then
	fatwrite mmc 0:1 0x43200000 boot.scr ${new_bootscr_size}
fi
setenv stdin serial,usbacm
setenv stdout serial,usbacm
setenv stderr serial,usbacm
