#!/bin/sh
## 34-hex2-data-relocs — build the data-relocs patcher.  Same pipeline
## as M2/kaem (M2 → catm → M0 → catm → hex2 → patcher) but with
## libc-full + hex2-linker.
set -eu

work="$TARGET/work/hex2-data-relocs"
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
  -f "$SOURCES/bootstrap-c/hex2-data-relocs.c" \
  -o hex2-data-relocs.M1

M1 --architecture amd64 --little-endian \
  -f "$src/M2libc/amd64/amd64_defs.M1" \
  -f "$src/M2libc/amd64/libc-full-Darwin.M1" \
  -f hex2-data-relocs.M1 \
  -o hex2-data-relocs.hex2

hex2 --architecture amd64 --little-endian \
  --base-address 0x600000 \
  -f "$src/M2libc/amd64/MACHO-amd64-lowdata.hex2" \
  -f hex2-data-relocs.hex2 \
  -o hex2-data-relocs

macho-patcher m2-segments hex2-data-relocs.hex2 hex2-data-relocs

dd if=/dev/zero of=hex2-data-relocs bs=1 count=1 seek=41943039 conv=notrunc 2>/dev/null || true
chmod +x hex2-data-relocs
install hex2-data-relocs "$TARGET/bin/hex2-data-relocs"
