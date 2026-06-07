#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)

CC=${CC:-mipsel-linux-uclibc-gcc}
DELAY=${DELAY:-15}

SRC="$REPO_ROOT/payload/rtsp_preload.c"
OUT="$REPO_ROOT/payload/rtsp_preload.so"

if ! command -v "$CC" >/dev/null 2>&1; then
  echo "Compiler not found: $CC" >&2
  echo "Set CC=/path/to/mipsel-linux-uclibc-gcc or install a compatible MIPS little-endian uClibc toolchain." >&2
  exit 1
fi

echo "Building RTSP payload"
echo "compiler: $CC"
echo "delay:    $DELAY seconds"
echo "source:   $SRC"
echo "output:   $OUT"

"$CC" \
  -Os \
  -fPIC \
  -shared \
  -DRTSP_INIT_DELAY_SECONDS="$DELAY" \
  -o "$OUT" \
  "$SRC" \
  -ldl \
  -lpthread

chmod 644 "$OUT"

echo "Done: $OUT"
if command -v file >/dev/null 2>&1; then
  file "$OUT"
fi
