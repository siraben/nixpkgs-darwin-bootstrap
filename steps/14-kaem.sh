#!/bin/sh
## 14-kaem — build kaem, the stage0 mini-shell.
##
## kaem runs simple command scripts with variable expansion (the
## interpreter stage0/live-bootstrap use for orchestration).  In this
## track the steps/ scripts run under Apple /bin/sh and no later step
## invokes target/bin/kaem; step 17 runs mes's kaem.run under /bin/sh.
## Building it completes the mescc-tools set from chain-built parts.
##
## Runs:     M2-darwin (step 08), M1 (step 12), hex2 (step 13),
##           macho-patcher (step 06); Apple dd, chmod, install, grep,
##           cat.
## Inputs:   sources/stage0-posix/mescc-tools/Kaem/{kaem.h,variable.c,
##           kaem_globals.c,kaem.c}, M2libc headers and libc .c files
##           (listed below), M2libc/amd64/{amd64_defs.M1,
##           libc-full-Darwin.M1,MACHO-amd64-lowdata.hex2}.
## Outputs:  target/bin/kaem.
## Verifies: grep for untranslated M1 tokens (see step 08); smoke
##           test — --help output contains a Usage line.
## Trust:    translation and layout by chain-built tools.  Apple dd
##           appends content-free zero padding; /bin/sh orchestrates.
set -eu

work="$TARGET/work/kaem"
mkdir -p "$work"
cd "$work"

src="$SOURCES/stage0-posix"

## Full M2libc build (see step 11 for the ordering rationale).
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

## Fail fast if M1 left any M1 mnemonic or DEFINE unexpanded (see
## step 08).
if grep -q 'sub_rdi\|lea_r9\|mov_rdi,rbp\|DWORD\|DEFINE' kaem.hex2; then
  echo "kaem hex2 contains untranslated M1 tokens" >&2
  exit 1
fi

## First link performed by the final hex2 (step 13).
## --base-address 0x600000 = __TEXT vmaddr of the lowdata template
## (see step 12).
hex2 \
  --architecture amd64 \
  --little-endian \
  --base-address 0x600000 \
  -f "$src/M2libc/amd64/MACHO-amd64-lowdata.hex2" \
  -f kaem.hex2 \
  -o kaem

macho-patcher m2-segments kaem.hex2 kaem

## Pad to the 0x2800000 __LINKEDIT file offset (see step 05).
dd if=/dev/zero of=kaem bs=1 count=1 seek=41943039 conv=notrunc 2>/dev/null || true
chmod +x kaem
install kaem "$TARGET/bin/kaem"

## Smoke test: usage text may land on stdout or stderr; check both.
"$TARGET/bin/kaem" --help > help.stdout 2> help.stderr
cat help.stdout help.stderr > help.combined
grep -q 'Usage:' help.combined
