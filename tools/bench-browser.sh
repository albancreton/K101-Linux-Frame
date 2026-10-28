#!/usr/bin/env bash
# Run the scroll benchmark on the frame in a given browser setup and print
# the result. The kiosk is stopped during the run and restarted afterwards.
#   tools/bench-browser.sh <name> <command run as the kiosk user>
# The command gets $URL; wrap it in `cage -s --` for a Wayland client.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
name=$1; cmd=$2
"$ROOT/tools/frame-ssh" "NO_KIOSK=${NO_KIOSK:-} bash -s" <<SH
systemctl stop kiosk bench 2>/dev/null; systemctl reset-failed bench 2>/dev/null
cat > /tmp/bench-run.sh <<'CMD'
#!/bin/sh
export URL=file:///usr/local/share/dashframe/scrollbench.html
$cmd
CMD
chmod 755 /tmp/bench-run.sh
rm -f /tmp/bench.out
(timeout 90 nc -l -N 127.0.0.1 8099 </dev/null > /tmp/bench.out 2>&1 &)
systemd-run --unit=bench -p User=kiosk -p PAMName=login -p TTYPath=/dev/tty1 \
	-p StandardInput=tty -p StandardOutput=journal -p StandardError=journal \
	-p "CapabilityBoundingSet=~CAP_WAKE_ALARM" -E XDG_SESSION_TYPE=wayland \
	/tmp/bench-run.sh >/dev/null
for i in \$(seq 1 60); do grep -q SCROLLBENCH /tmp/bench.out 2>/dev/null && break; sleep 1; done
r=\$(grep -o "SCROLLBENCH[^ ]*" /tmp/bench.out | head -1 | sed 's/^SCROLLBENCH//' | sed 's/%22/"/g; s/%7B/{/g; s/%7D/}/g; s/%3A/:/g; s/%2C/,/g; s/%2F/\//g')
echo "$name: \${r:-no result} temp \$(( \$(cat /sys/class/thermal/thermal_zone0/temp)/1000 ))C"
systemctl stop bench; systemctl reset-failed bench 2>/dev/null; pkill -x nc || true
[ -n "${NO_KIOSK:-}" ] || systemctl start kiosk
SH
