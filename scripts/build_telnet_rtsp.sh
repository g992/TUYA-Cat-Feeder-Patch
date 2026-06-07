#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)

. "$SCRIPT_DIR/lib/common.sh"
. "$SCRIPT_DIR/lib/layout.sh"

BASE_FIRMWARE=${1:-"$REPO_DIR/$FIRMWARE_NAME_DEFAULT"}
SOURCE_ROOTFS=${SOURCE_ROOTFS:-"$REPO_DIR/extracted/rootfs"}
SOURCE_SYSTEM=${SOURCE_SYSTEM:-"$REPO_DIR/extracted/system"}
OUTPUT_FIRMWARE=${2:-"$REPO_DIR/dist/${FIRMWARE_NAME_DEFAULT%.Bin}.telnet_rtsp.Bin"}

[ -d "$SOURCE_ROOTFS" ] || die "rootfs not extracted. Run: ./scripts/extract.sh"
[ -d "$SOURCE_SYSTEM" ] || die "system not extracted. Run: ./scripts/extract.sh"
[ -f "$REPO_DIR/payload/rtsp_preload.so" ] || die "payload/rtsp_preload.so not found"

echo "==> Applying telnet + RTSP patch"
copy_file_or_die "$REPO_DIR/patches/rcS.telnet_rtsp" "$SOURCE_ROOTFS/etc/init.d/rcS"
copy_file_or_die "$REPO_DIR/payload/rtsp_preload.so" "$SOURCE_SYSTEM/lib/rtsp_preload.so"

# Important: tuya_test must stay the vendor ELF binary.
if [ -f "$SOURCE_SYSTEM/bin/tuya_test.real" ]; then
  die "found system/bin/tuya_test.real. Do not use shell wrapper; restore original ELF as system/bin/tuya_test"
fi

. "$SCRIPT_DIR/lib/rebuild_image.sh"
