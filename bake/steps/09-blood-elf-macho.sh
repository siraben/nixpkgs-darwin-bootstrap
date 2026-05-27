#!/bin/sh
## 09-blood-elf-macho — assemble blood-elf-macho footer generator.
## Pipeline mirrors the Nix recipe: M2 → catm defs+libc+body →
## M0 → catm MACHO_template+hex2 → hex2 → macho-patcher → pad.
set -eu

work="$TARGET/work/blood-elf-macho"
mkdir -p "$work"
cd "$work"

src="$SOURCES/stage0-posix"

M2-darwin \
  --architecture amd64 \
  -f "$src/M2libc/amd64/Darwin/bootstrap.c" \
  -f "$src/M2libc/bootstrappable.c" \
  -f "$src/mescc-tools/stringify.c" \
  -f "$src/mescc-tools/blood-elf.c" \
  --bootstrap-mode \
  -o blood-macho-0.M1

catm-darwin blood-macho-0-0.M1 \
  "$src/M2libc/amd64/amd64_defs.M1" \
  "$src/M2libc/amd64/libc-core-Darwin.M1" \
  blood-macho-0.M1

M0-darwin blood-macho-0-0.M1 blood-macho-0.hex2

if grep -q 'sub_rdi\|lea_r9\|mov_rdi,rbp\|DWORD\|DEFINE' blood-macho-0.hex2; then
  echo "blood-macho-0 hex2 contains untranslated M1 tokens" >&2
  exit 1
fi

catm-darwin blood-macho-0-0.hex2 \
  "$src/M2libc/amd64/MACHO-amd64-lowdata.hex2" \
  blood-macho-0.hex2

hex2-darwin blood-macho-0-0.hex2 blood-macho-0
macho-patcher m2-segments blood-macho-0.hex2 blood-macho-0

target_size=41943040
dd if=/dev/zero of=blood-macho-0 bs=1 count=1 \
  seek=$((target_size - 1)) conv=notrunc 2>/dev/null || true

chmod +x blood-macho-0
install blood-macho-0 "$TARGET/bin/blood-macho-0"
