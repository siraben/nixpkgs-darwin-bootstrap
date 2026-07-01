#!/bin/sh
## 16-m2-planet — M2-Planet binary built by M1+hex2 (not M0).
##
## Different from phase 8 (M2) which uses bootstrap-mode and links via
## M0+macho-patcher.  This M2-Planet uses libc-full and is what mes's
## kaem.run invokes by name.
set -eu

work="$TARGET/work/m2-planet"
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
  -f "$src/M2libc/amd64/Darwin/sys/stat.c" \
  -f "$src/M2libc/ctype.c" \
  -f "$src/M2libc/stdlib.c" \
  -f "$src/M2libc/string.c" \
  -f "$src/M2libc/stdarg.h" \
  -f "$src/M2libc/stdio.h" \
  -f "$src/M2libc/stdio.c" \
  -f "$src/M2libc/bootstrappable.c" \
  -f "$src/M2-Planet/cc.h" \
  -f "$src/M2-Planet/cc_globals.c" \
  -f "$src/M2-Planet/cc_reader.c" \
  -f "$src/M2-Planet/cc_strings.c" \
  -f "$src/M2-Planet/cc_types.c" \
  -f "$src/M2-Planet/cc_emit.c" \
  -f "$src/M2-Planet/cc_core.c" \
  -f "$src/M2-Planet/cc_macro.c" \
  -f "$src/M2-Planet/cc.c" \
  -o M2-Planet.M1

M1 \
  --architecture amd64 \
  --little-endian \
  -f "$src/M2libc/amd64/amd64_defs.M1" \
  -f "$src/M2libc/amd64/libc-full-Darwin.M1" \
  -f M2-Planet.M1 \
  -o M2-Planet.hex2

if grep -q 'sub_rdi\|lea_r9\|mov_rdi,rbp\|DWORD\|DEFINE' M2-Planet.hex2; then
  echo "M2-Planet hex2 contains untranslated M1 tokens" >&2
  exit 1
fi

hex2 \
  --architecture amd64 \
  --little-endian \
  --base-address 0x600000 \
  -f "$src/M2libc/amd64/MACHO-amd64-lowdata.hex2" \
  -f M2-Planet.hex2 \
  -o M2-Planet

macho-patcher m2-segments M2-Planet.hex2 M2-Planet

dd if=/dev/zero of=M2-Planet bs=1 count=1 seek=41943039 conv=notrunc 2>/dev/null || true
chmod +x M2-Planet
install M2-Planet "$TARGET/bin/M2-Planet"

## Smoke test
"$TARGET/bin/M2-Planet" --help > help.stdout 2>&1
grep -q 'Usage: M2-Planet' help.stdout
