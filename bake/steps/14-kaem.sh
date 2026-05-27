#!/bin/sh
## 14-kaem — mini-shell (kaem).  Once built, kaem can replace /bin/sh
## as the build-orchestrator for all downstream phases (mes-m2, tcc,
## gcc, ...).
set -eu

work="$TARGET/work/kaem"
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
  -f "$src/mescc-tools/Kaem/kaem.h" \
  -f "$src/mescc-tools/Kaem/variable.c" \
  -f "$src/mescc-tools/Kaem/kaem_globals.c" \
  -f "$src/mescc-tools/Kaem/kaem.c" \
  -o kaem.M1

M1 \
  --architecture amd64 \
  --little-endian \
  -f "$src/M2libc/amd64/amd64_defs.M1" \
  -f "$src/M2libc/amd64/libc-full-Darwin.M1" \
  -f kaem.M1 \
  -o kaem.hex2

if grep -q 'sub_rdi\|lea_r9\|mov_rdi,rbp\|DWORD\|DEFINE' kaem.hex2; then
  echo "kaem hex2 contains untranslated M1 tokens" >&2
  exit 1
fi

hex2 \
  --architecture amd64 \
  --little-endian \
  --base-address 0x600000 \
  -f "$src/M2libc/amd64/MACHO-amd64-lowdata.hex2" \
  -f kaem.hex2 \
  -o kaem

macho-patcher m2-segments kaem.hex2 kaem

dd if=/dev/zero of=kaem bs=1 count=1 seek=41943039 conv=notrunc 2>/dev/null || true
chmod +x kaem
install kaem "$TARGET/bin/kaem"

## Smoke test
"$TARGET/bin/kaem" --help > help.stdout 2> help.stderr
cat help.stdout help.stderr > help.combined
grep -q 'Usage:' help.combined
