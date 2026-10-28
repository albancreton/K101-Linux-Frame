# dashframe SD boot script (FAT partition 1).
#
# Boots Linux from the card. If the file "dashframe-fel" exists on this
# partition, drops into USB FEL mode instead (dev loop; `touch
# /boot/firmware/dashframe-fel && reboot` on the frame, or remove the card).

if test -e ${devtype} ${devnum}:${distro_bootpart} dashframe-fel; then
	echo "dashframe: entering FEL"
	for i in 1 2; do gpio set PH0; sleep 0.3; gpio clear PH0; sleep 0.3; done
	gpio set PH0
	dcache off
	icache off
	go 0xffff0020
fi

load ${devtype} ${devnum}:${distro_bootpart} ${kernel_addr_r} zImage
load ${devtype} ${devnum}:${distro_bootpart} ${fdt_addr_r} sun8i-a33-k101-frame.dtb

# systemd takes over feeding the watchdog (RuntimeWatchdogSec); a kernel that
# never gets there resets after 16 s.
wdt dev watchdog@1c20ca0
wdt start 16000

setenv bootargs root=/dev/mmcblk0p2 rootwait rw quiet console=ttyGS0,115200 console=tty1 fbcon=rotate:1 net.ifnames=0 g_cdc.idVendor=0x1f3a g_cdc.idProduct=0x1011 g_cdc.host_addr=02:da:5f:00:00:01 g_cdc.dev_addr=02:da:5f:00:00:02
bootz ${kernel_addr_r} - ${fdt_addr_r}
