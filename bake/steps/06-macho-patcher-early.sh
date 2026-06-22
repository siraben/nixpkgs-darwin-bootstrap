#!/bin/sh
## 06-macho-patcher-early — catm(amd64_defs, amd64_byte_defs, macho-patcher-m0.M1)
## -> M0 -> catm(MACHO-amd64 template, body) -> hex2 -> pad to 0x2800000.  The
## cycle-breaker (M0 + hex2 only, no M2-Planet).  Mirrors macho-patcher-early.nix.
set -eu

work="$TARGET/work/mpe"; mkdir -p "$work"; cd "$work"
catm-darwin combined.M0 \
  "$SOURCES/amd64_defs.M1" \
  "$SOURCES/amd64_byte_defs.M1" \
  "$SOURCES/macho-patcher-m0.M1"
M0-darwin combined.M0 combined.hex2
catm-darwin final.hex2 "$SOURCES/MACHO-amd64.hex2" combined.hex2
hex2-darwin final.hex2 "$TARGET/bin/macho-patcher"
dd if=/dev/zero of="$TARGET/bin/macho-patcher" bs=1 count=1 seek=41943039 conv=notrunc
chmod +x "$TARGET/bin/macho-patcher"
