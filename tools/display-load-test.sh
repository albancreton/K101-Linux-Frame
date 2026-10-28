#!/usr/bin/env bash
# Show linetest.html on the frame and put memory load on during the second
# half of every minute, for MINUTES minutes (default 3), then restore the kiosk.
# Watch the panel: lines of the wrong colour only during "LOAD ON" mean the
# display engine is starved of memory bandwidth.
#   tools/display-load-test.sh [MINUTES] ["command run while loaded"]
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
minutes=${1:-3}
load=${2:-'for c in 1 2 3 4; do dd if=/dev/zero of=/dev/null bs=16M count=100000 2>/dev/null & done; wait'}
"$ROOT/tools/frame-ssh" bash -s <<SH
systemctl stop kiosk linetest 2>/dev/null; systemctl reset-failed linetest 2>/dev/null
systemd-run --unit=linetest -p User=kiosk -p PAMName=login -p TTYPath=/dev/tty1 \
	-p StandardInput=tty -p StandardOutput=journal -p StandardError=journal \
	-p "CapabilityBoundingSet=~CAP_WAKE_ALARM" -p TimeoutStopSec=3 -E XDG_SESSION_TYPE=wayland \
	/usr/bin/cage -s -- /bin/sh -c 'wlr-randr --output DSI-1 --transform 270; exec cog --platform=wl file:///usr/local/share/dashframe/linetest.html' >/dev/null
end=\$(( \$(date +%s) + $minutes * 60 ))
while [ \$(date +%s) -lt \$end ]; do
	s=\$(date +%-S)
	if [ \$s -ge 30 ]; then
		echo "\$(date +%T) load on"
		timeout \$(( 60 - s )) sh -c '$load' || true
	else
		sleep \$(( 30 - s ))
	fi
done
systemctl stop linetest; systemctl reset-failed linetest 2>/dev/null
systemctl start kiosk
SH
