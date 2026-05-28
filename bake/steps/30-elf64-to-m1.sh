#!/bin/sh
## 30-elf64-to-m1 — assemble the ELF-to-M1 converter.
## Uses M1 + hex2 + the hand-written tools/elf64-to-m1.M1 source.
set -eu

work="$TARGET/work/elf64-to-m1"
rm -rf "$work"
mkdir -p "$work"
cd "$work"

src="$SOURCES/stage0-posix"

M1 \
  --architecture amd64 \
  --little-endian \
  -f "$src/M2libc/amd64/amd64_defs.M1" \
  -f "$SOURCES/tools/elf64-to-m1.M1" \
  -o elf64-to-m1.hex2

hex2 \
  --architecture amd64 \
  --little-endian \
  --base-address 0x1000000 \
  -f "$src/M2libc/amd64/MACHO-amd64.hex2" \
  -f elf64-to-m1.hex2 \
  -o elf64-to-m1

dd if=/dev/zero of=elf64-to-m1 bs=1 count=1 seek=41943039 conv=notrunc 2>/dev/null || true
chmod +x elf64-to-m1
install elf64-to-m1 "$TARGET/bin/elf64-to-m1"
