# Proof-of-life script for the first SD boot (no serial console needed).
# 1. Blinks the backlight (PH0) 5 times: U-Boot is running from DRAM and read the SD card.
# 2. Writes the U-Boot environment to dashframe-pol.txt on this FAT partition: SD writes work.
# 3. Slow-blinks 3 times, then powers off via the AXP223.

echo "dashframe: proof-of-life"
for i in 1 2 3 4 5; do gpio set PH0; sleep 0.3; gpio clear PH0; sleep 0.3; done
gpio set PH0

setenv pol_status "u-boot ran from ${devtype} ${devnum}:${distro_bootpart}"
env export -t ${scriptaddr}
fatwrite ${devtype} ${devnum}:${distro_bootpart} ${scriptaddr} dashframe-pol.txt ${filesize}

for i in 1 2 3; do gpio clear PH0; sleep 1; gpio set PH0; sleep 1; done
poweroff
