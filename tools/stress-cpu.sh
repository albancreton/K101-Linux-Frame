#!/bin/sh
# Runs ON the frame: all four cores hash 32 MiB of zeros in a loop for
# DURATION seconds, checking every result (an undervolted CPU tends to
# compute wrong hashes before it crashes), logging clock and temperature.
#   tools/frame-ssh 'sh -s 180' < tools/stress-cpu.sh
DURATION=${1:-180}
ref=$(head -c 32M /dev/zero | sha256sum)
end=$(( $(date +%s) + DURATION ))
rm -f /tmp/stress.bad /tmp/stress.runs
for c in 1 2 3 4; do
	(while [ "$(date +%s)" -lt $end ]; do
		s=$(head -c 32M /dev/zero | sha256sum)
		[ "$s" = "$ref" ] || echo bad >> /tmp/stress.bad
		echo run >> /tmp/stress.runs
	done) &
done
while [ "$(date +%s)" -lt $end ]; do
	sleep 20
	echo "$(date +%T) $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq) kHz" \
		"$(( $(cat /sys/class/thermal/thermal_zone0/temp) / 1000 ))C load $(cut -d' ' -f1 /proc/loadavg)"
done
wait
echo "hashes: $(wc -l < /tmp/stress.runs), mismatches: $(cat /tmp/stress.bad 2>/dev/null | wc -l)"
echo "throttle stats (time in each freq, 10ms units):"
cat /sys/devices/system/cpu/cpu0/cpufreq/stats/time_in_state 2>/dev/null | awk '$2>0' | tail -5
dmesg | grep -iE "oops|bug:|panic|critical temp" | tail -3
