#!/bin/sh
## 11-hex2-1 — second hex2 (with linker features), built by M1-0.
## M2 → M1-0 → catm MACHO + body hex2 → hex2 (phase 2) →
## macho-patcher → pad.
set -eu

work="$TARGET/work/hex2-1"
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
  -o hex2_linker-0.M1

M1-0 \
  --architecture amd64 \
  --little-endian \
  -f "$src/M2libc/amd64/amd64_defs.M1" \
  -f "$src/M2libc/amd64/libc-full-Darwin.M1" \
  -f hex2_linker-0.M1 \
  -o hex2_linker-0.hex2

if grep -q 'sub_rdi\|lea_r9\|mov_rdi,rbp\|DWORD\|DEFINE' hex2_linker-0.hex2; then
  echo "hex2-1 hex2 contains untranslated M1 tokens" >&2
  exit 1
fi

catm-darwin hex2-1-0.hex2 \
  "$src/M2libc/amd64/MACHO-amd64-lowdata.hex2" \
  hex2_linker-0.hex2

hex2-darwin hex2-1-0.hex2 hex2-1
macho-patcher m2-segments hex2_linker-0.hex2 hex2-1

dd if=/dev/zero of=hex2-1 bs=1 count=1 seek=41943039 conv=notrunc 2>/dev/null || true
chmod +x hex2-1
install hex2-1 "$TARGET/bin/hex2-1"

## Smoke test
"$TARGET/bin/hex2-1" --help > help.stdout 2> help.stderr
cat help.stdout help.stderr > help.combined
grep -q 'Usage:' help.combined
