#!/bin/sh
## 13-hex2-linker — final hex2 (linker form).  Built by M1 (phase 9)
## linking against libc-full.  This is the hex2 used by all downstream
## (mes, tinycc, gcc) phases.
set -eu

work="$TARGET/work/hex2-linker"
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
  -f "$src/M2libc/stdarg.h" \
  -f "$src/M2libc/stdio.h" \
  -f "$src/M2libc/stdio.c" \
  -f "$src/M2libc/bootstrappable.c" \
  -f "$src/mescc-tools/hex2.h" \
  -f "$src/mescc-tools/hex2_linker.c" \
  -f "$src/mescc-tools/hex2_word.c" \
  -f "$src/mescc-tools/hex2.c" \
  -o hex2_linker-2.M1

M1 \
  --architecture amd64 \
  --little-endian \
  -f "$src/M2libc/amd64/amd64_defs.M1" \
  -f "$src/M2libc/amd64/libc-full-Darwin.M1" \
  -f hex2_linker-2.M1 \
  -o hex2_linker-2.hex2

if grep -q 'sub_rdi\|lea_r9\|mov_rdi,rbp\|DWORD\|DEFINE' hex2_linker-2.hex2; then
  echo "hex2-linker hex2 contains untranslated M1 tokens" >&2
  exit 1
fi

hex2-1 \
  --architecture amd64 \
  --little-endian \
  --base-address 0x600000 \
  -f "$src/M2libc/amd64/MACHO-amd64-lowdata.hex2" \
  -f hex2_linker-2.hex2 \
  -o hex2

macho-patcher m2-segments hex2_linker-2.hex2 hex2

dd if=/dev/zero of=hex2 bs=1 count=1 seek=41943039 conv=notrunc 2>/dev/null || true
chmod +x hex2
install hex2 "$TARGET/bin/hex2"

## Smoke test
"$TARGET/bin/hex2" --help > help.stdout 2> help.stderr
cat help.stdout help.stderr > help.combined
grep -q 'Usage:' help.combined
