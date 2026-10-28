# SD-card boot script: hand the SoC back to the BootROM's USB FEL mode, so the
# host can load U-Boot/kernel/initramfs with sunxi-fel. Two backlight blinks,
# then the backlight stays on while in FEL. Remove the card to boot Android.
# When U-Boot itself was loaded over FEL, do nothing: U-Boot falls through to
# its prompt (reachable over USB ACM, see fel-console.cmd).
if test -n "${fel_booted}"; then echo "FEL-booted: not re-entering FEL"; exit; fi
for i in 1 2; do gpio set PH0; sleep 0.3; gpio clear PH0; sleep 0.3; done
gpio set PH0
dcache off
icache off
go 0xffff0020
