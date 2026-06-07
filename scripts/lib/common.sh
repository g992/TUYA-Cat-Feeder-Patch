#!/bin/sh
set -eu

script_dir() {
  CDPATH= cd -- "$(dirname -- "$0")" && pwd
}

repo_root_from_script() {
  # scripts/foo.sh -> repo root
  script_path=$(script_dir)
  CDPATH= cd -- "$script_path/.." && pwd
}

die() {
  echo "error: $*" >&2
  exit 1
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "$1 not found"
}

file_size() {
  # Portable enough for Linux and macOS.
  if stat -c '%s' "$1" >/dev/null 2>&1; then
    stat -c '%s' "$1"
  else
    stat -f '%z' "$1"
  fi
}

normalize_text_file() {
  file=$1
  [ -f "$file" ] || return 0
  # Remove CRLF if perl is available; keep silent otherwise.
  if command -v perl >/dev/null 2>&1; then
    perl -pi -e 's/\r$//' "$file"
  fi
}

copy_file_or_die() {
  src=$1
  dst=$2
  [ -f "$src" ] || die "file not found: $src"
  mkdir -p "$(dirname "$dst")"
  cp "$src" "$dst"
}
