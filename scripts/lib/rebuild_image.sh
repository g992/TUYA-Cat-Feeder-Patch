#!/bin/sh
set -eu

# This file is meant to be sourced by build scripts.
# Required variables:
#   REPO_DIR, SOURCE_ROOTFS, SOURCE_SYSTEM, BASE_FIRMWARE, OUTPUT_FIRMWARE

. "$REPO_DIR/scripts/lib/common.sh"
. "$REPO_DIR/scripts/lib/layout.sh"

need_cmd mksquashfs

[ -f "$BASE_FIRMWARE" ] || die "base firmware not found: $BASE_FIRMWARE"

ACTUAL_SIZE=$(file_size "$BASE_FIRMWARE")
[ "$ACTUAL_SIZE" -eq "$FIRMWARE_SIZE" ] || die "unexpected base firmware size: $ACTUAL_SIZE bytes, expected $FIRMWARE_SIZE"

TMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/feeder-fw.XXXXXX")
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT INT TERM

NEW_ROOTFS="$TMP_DIR/rootfs.squashfs"
NEW_SYSTEM="$TMP_DIR/system.squashfs"

normalize_source_tree() {
  if [ -d "$SOURCE_ROOTFS" ]; then
    chmod 755 "$SOURCE_ROOTFS/linuxrc" 2>/dev/null || true
    chmod 755 "$SOURCE_ROOTFS/etc/init.d/rcS" 2>/dev/null || true
    normalize_text_file "$SOURCE_ROOTFS/etc/init.d/rcS"
  fi

  if [ -d "$SOURCE_SYSTEM" ]; then
    chmod 755 "$SOURCE_SYSTEM/bin/tuya_test" 2>/dev/null || true
    chmod 644 "$SOURCE_SYSTEM/lib/rtsp_preload.so" 2>/dev/null || true
  fi
}

inject_partition() {
  src_img=$1
  dst_fw=$2
  offset=$3
  part_size=$4
  label=$5

  img_size=$(file_size "$src_img")
  [ "$img_size" -le "$part_size" ] || die "new $label is too large: $img_size bytes > $part_size bytes partition"

  echo "==> Injecting $label at offset $offset"
  dd if="$src_img" of="$dst_fw" bs=1 seek="$offset" conv=notrunc >/dev/null 2>&1

  pad_size=$((part_size - img_size))
  if [ "$pad_size" -gt 0 ]; then
    dd if=/dev/zero of="$dst_fw" bs=1 seek=$((offset + img_size)) count="$pad_size" conv=notrunc >/dev/null 2>&1
  fi
}

normalize_source_tree

mkdir -p "$(dirname "$OUTPUT_FIRMWARE")"
cp "$BASE_FIRMWARE" "$OUTPUT_FIRMWARE"

NEW_ROOTFS_SIZE=0
if [ -d "$SOURCE_ROOTFS" ]; then
  echo "==> Building rootfs squashfs"
  mksquashfs \
    "$SOURCE_ROOTFS" \
    "$NEW_ROOTFS" \
    -noappend \
    -no-xattrs \
    -comp "$ROOTFS_COMPRESSION" \
    -b "$ROOTFS_BLOCK_SIZE" \
    -all-root >/dev/null

  NEW_ROOTFS_SIZE=$(file_size "$NEW_ROOTFS")
  inject_partition "$NEW_ROOTFS" "$OUTPUT_FIRMWARE" "$ROOTFS_OFFSET" "$ROOTFS_PARTITION_SIZE" "rootfs"
else
  echo "==> Skipping rootfs rebuild; directory not found: $SOURCE_ROOTFS"
fi

NEW_SYSTEM_SIZE=0
if [ -d "$SOURCE_SYSTEM" ]; then
  echo "==> Building system/appfs squashfs"
  mksquashfs \
    "$SOURCE_SYSTEM" \
    "$NEW_SYSTEM" \
    -noappend \
    -no-xattrs \
    -comp "$SYSTEM_COMPRESSION" \
    -b "$SYSTEM_BLOCK_SIZE" \
    -all-root >/dev/null

  NEW_SYSTEM_SIZE=$(file_size "$NEW_SYSTEM")
  inject_partition "$NEW_SYSTEM" "$OUTPUT_FIRMWARE" "$SYSTEM_OFFSET" "$SYSTEM_PARTITION_SIZE" "system/appfs"
else
  echo "==> Skipping system rebuild; directory not found: $SOURCE_SYSTEM"
fi

FINAL_SIZE=$(file_size "$OUTPUT_FIRMWARE")
[ "$FINAL_SIZE" -eq "$FIRMWARE_SIZE" ] || die "unexpected output size: $FINAL_SIZE bytes != $FIRMWARE_SIZE bytes"

echo
echo "Done."
echo "new rootfs size: $NEW_ROOTFS_SIZE bytes"
echo "new system size: $NEW_SYSTEM_SIZE bytes"
echo "output firmware: $OUTPUT_FIRMWARE"
