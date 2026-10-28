#!/usr/bin/env bash
# Fetch the pinned U-Boot and Linux trees into src/ (shallow clones).
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
mkdir -p "$ROOT/src"
fetch() {
	local dir=$1 url=$2 tag=$3
	if [ -d "$ROOT/src/$dir/.git" ]; then
		echo "src/$dir already present"
		return
	fi
	git clone --depth 1 --branch "$tag" "$url" "$ROOT/src/$dir"
}
fetch u-boot https://source.denx.de/u-boot/u-boot.git v2026.10
fetch linux https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git v6.18.59
