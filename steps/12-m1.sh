#!/bin/sh
## 12-m1 — full M1 assembler.  Uses hex2-1 as the linker instead of
## the macho-patcher pipeline used by earlier phases.
set -eu

work="$TARGET/work/m1"
mkdir -p "$work"
cd "$work"

src="$SOURCES/stage0-posix"

M2-darwin \
  --architecture amd64 \
  -f "$src/M2libc/sys/types.h" \
  -f "$src/M2libc/stddef.h" \
  -f "$src/M2libc/sys/utsname.h" \
  -f "$src/M2libc/amd64/Darwin/fcntl.c" \
  -f "$src/M2libc/fcntl.c" \
  -f "$src/M2libc/amd64/Darwin/unistd.c" \
  -f "$src/M2libc/stdarg.h" \
  -f "$src/M2libc/string.c" \
  -f "$src/M2libc/ctype.c" \
  -f "$src/M2libc/stdlib.c" \
  -f "$src/M2libc/stdio.h" \
  -f "$src/M2libc/stdio.c" \
  -f "$src/M2libc/bootstrappable.c" \
  -f "$src/mescc-tools/stringify.c" \
  -f "$src/mescc-tools/M1-macro.c" \
  -o M1-macro-1.M1

M1-0 \
  --architecture amd64 \
  --little-endian \
  -f "$src/M2libc/amd64/amd64_defs.M1" \
  -f "$src/M2libc/amd64/libc-full-Darwin.M1" \
  -f M1-macro-1.M1 \
  -o M1-macro-1.hex2

if grep -q 'sub_rdi\|lea_r9\|mov_rdi,rbp\|DWORD\|DEFINE' M1-macro-1.hex2; then
  echo "M1 hex2 contains untranslated M1 tokens" >&2
  exit 1
fi

hex2-1 \
  --architecture amd64 \
  --little-endian \
  --base-address 0x600000 \
  -f "$src/M2libc/amd64/MACHO-amd64-lowdata.hex2" \
  -f M1-macro-1.hex2 \
  -o M1

macho-patcher m2-segments M1-macro-1.hex2 M1

dd if=/dev/zero of=M1 bs=1 count=1 seek=41943039 conv=notrunc 2>/dev/null || true
chmod +x M1
install M1 "$TARGET/bin/M1"

## Smoke test
"$TARGET/bin/M1" --help > help.stdout 2> help.stderr
cat help.stdout help.stderr > help.combined
grep -q 'Usage:' help.combined
