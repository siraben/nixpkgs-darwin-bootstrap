#!/bin/sh
## 43-m1-to-hex2 — assemble m1-to-hex2 binary (.M1 → .hex2 converter).
set -eu

work="$TARGET/work/m1-to-hex2"
rm -rf "$work"
mkdir -p "$work"
cd "$work"

src="$SOURCES/stage0-posix"

M2-darwin \
  --architecture amd64 \
  -f "$src/M2libc/sys/types.h" \
  -f "$src/M2libc/stddef.h" \
  -f "$src/M2libc/sys/utsname.h" \
  -f "$src/M2libc/amd64/Darwin/unistd.c" \
  -f "$src/M2libc/amd64/Darwin/fcntl.c" \
  -f "$src/M2libc/fcntl.c" \
  -f "$src/M2libc/ctype.c" \
  -f "$src/M2libc/stdlib.c" \
  -f "$src/M2libc/string.c" \
  -f "$src/M2libc/stdarg.h" \
  -f "$src/M2libc/stdio.h" \
  -f "$src/M2libc/stdio.c" \
  -f "$src/M2libc/bootstrappable.c" \
  -f "$SOURCES/bootstrap-c/m1-to-hex2.c" \
  -o m1-to-hex2.M1

M1 --architecture amd64 --little-endian \
  -f "$src/M2libc/amd64/amd64_defs.M1" \
  -f "$src/M2libc/amd64/libc-full-Darwin.M1" \
  -f m1-to-hex2.M1 \
  -o m1-to-hex2.hex2

hex2 --architecture amd64 --little-endian \
  --base-address 0x600000 \
  -f "$src/M2libc/amd64/MACHO-amd64-lowdata.hex2" \
  -f m1-to-hex2.hex2 \
  -o m1-to-hex2

macho-patcher m2-segments m1-to-hex2.hex2 m1-to-hex2

dd if=/dev/zero of=m1-to-hex2 bs=1 count=1 seek=41943039 conv=notrunc 2>/dev/null || true
chmod +x m1-to-hex2
install m1-to-hex2 "$TARGET/bin/m1-to-hex2"
