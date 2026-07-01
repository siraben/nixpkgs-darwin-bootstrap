#!/bin/sh
## 10-m1-0 — initial M1 macro assembler.  Same pipeline as M2:
## M2 → catm defs + libc + body → M0 → catm MACHO + hex2 →
## hex2 → macho-patcher → pad.
set -eu

work="$TARGET/work/m1-0"
mkdir -p "$work"
cd "$work"

src="$SOURCES/stage0-posix"

M2-darwin \
  --architecture amd64 \
  -f "$src/M2libc/amd64/Darwin/bootstrap.c" \
  -f "$src/M2libc/bootstrappable.c" \
  -f "$src/mescc-tools/stringify.c" \
  -f "$src/mescc-tools/M1-macro.c" \
  --bootstrap-mode \
  -o M1-macro-0.M1

catm-darwin M1-0-0.M1 \
  "$src/M2libc/amd64/amd64_defs.M1" \
  "$src/M2libc/amd64/libc-core-Darwin.M1" \
  M1-macro-0.M1

M0-darwin M1-0-0.M1 M1-0.hex2

if grep -q 'sub_rdi\|lea_r9\|mov_rdi,rbp\|DWORD\|DEFINE' M1-0.hex2; then
  echo "M1-0 hex2 contains untranslated M1 tokens" >&2
  exit 1
fi

catm-darwin M1-0-0.hex2 \
  "$src/M2libc/amd64/MACHO-amd64-lowdata.hex2" \
  M1-0.hex2

hex2-darwin M1-0-0.hex2 M1-0
macho-patcher m2-segments M1-0.hex2 M1-0

dd if=/dev/zero of=M1-0 bs=1 count=1 seek=41943039 conv=notrunc 2>/dev/null || true
chmod +x M1-0
install M1-0 "$TARGET/bin/M1-0"

## Smoke test
"$TARGET/bin/M1-0" --help > help.stdout 2> help.stderr
grep -q 'Usage:' help.stderr
