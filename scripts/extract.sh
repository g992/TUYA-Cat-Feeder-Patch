#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)

. "$SCRIPT_DIR/lib/common.sh"
. "$SCRIPT_DIR/lib/layout.sh"

need_cmd binwalk
need_cmd unsquashfs

FIRMWARE_PATH=${1:-"$REPO_DIR/$FIRMWARE_NAME_DEFAULT"}
OUTPUT_DIR=${2:-"$REPO_DIR/extracted"}

[ -f "$FIRMWARE_PATH" ] || die "firmware not found: $FIRMWARE_PATH"

ACTUAL_SIZE=$(file_size "$FIRMWARE_PATH")
[ "$ACTUAL_SIZE" -eq "$FIRMWARE_SIZE" ] || die "unexpected firmware size: $ACTUAL_SIZE bytes, expected $FIRMWARE_SIZE"

ROOTFS_DIR="$OUTPUT_DIR/rootfs"
SYSTEM_DIR="$OUTPUT_DIR/system"
REPORT_PATH="$OUTPUT_DIR/binwalk.txt"
LAYOUT_PATH="$OUTPUT_DIR/layout.txt"

rm -rf "$ROOTFS_DIR" "$SYSTEM_DIR"
mkdir -p "$OUTPUT_DIR"

echo "==> Analyzing firmware"
echo "    input: $FIRMWARE_PATH"
binwalk "$FIRMWARE_PATH" | tee "$REPORT_PATH"

cat > "$LAYOUT_PATH" <<EOF
firmware_path=$FIRMWARE_PATH
firmware_size=$FIRMWARE_SIZE
kernel_offset=$KERNEL_OFFSET
kernel_size=$KERNEL_SIZE
rootfs_offset=$ROOTFS_OFFSET
rootfs_partition_size=$ROOTFS_PARTITION_SIZE
rootfs_compression=$ROOTFS_COMPRESSION
rootfs_block_size=$ROOTFS_BLOCK_SIZE
ro_offset=$RO_OFFSET
ro_partition_size=$RO_PARTITION_SIZE
system_offset=$SYSTEM_OFFSET
system_partition_size=$SYSTEM_PARTITION_SIZE
system_compression=$SYSTEM_COMPRESSION
system_block_size=$SYSTEM_BLOCK_SIZE
EOF

echo "==> Extracting rootfs"
unsquashfs -d "$ROOTFS_DIR" -o "$ROOTFS_OFFSET" "$FIRMWARE_PATH"

echo "==> Extracting system/appfs"
unsquashfs -d "$SYSTEM_DIR" -o "$SYSTEM_OFFSET" "$FIRMWARE_PATH"

echo
echo "Done."
echo "rootfs:  $ROOTFS_DIR"
echo "system:  $SYSTEM_DIR"
echo "report:  $REPORT_PATH"
echo "layout:  $LAYOUT_PATH"
