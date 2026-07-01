#!/bin/sh
## 12-m1 — build M1, the full macro assembler.
##
## Same M1-macro.c program as step 10, compiled with the full M2libc
## file list (string.c included, no --bootstrap-mode) and linked
## against libc-full-Darwin.M1.  First binary linked by hex2-1 (step
## 11), which takes the header template and program text as separate
## -f inputs at --base-address.  Installed as `M1`, the assembler
## invoked by steps 13, 14, 16, 18, 21 and by mescc via the M1
## environment variable (steps 20-21).
##
## Runs:     M2-darwin (step 08), M1-0 (step 10), hex2-1 (step 11),
##           macho-patcher (step 06); Apple dd, chmod, install, grep,
##           cat.
## Inputs:   sources/stage0-posix/mescc-tools/{stringify.c,
##           M1-macro.c}, M2libc headers and libc .c files (listed
##           below), M2libc/amd64/{amd64_defs.M1,libc-full-Darwin.M1,
##           MACHO-amd64-lowdata.hex2}.
## Outputs:  target/bin/M1.
## Verifies: grep for untranslated M1 tokens (see step 08); smoke
##           test — --help output contains a Usage line.
## Trust:    translation and layout by chain-built tools.  Apple dd
##           appends content-free zero padding; /bin/sh orchestrates.
set -eu

work="$TARGET/work/m1"
mkdir -p "$work"
cd "$work"

src="$SOURCES/stage0-posix"

## Full M2libc build (see step 11 for the ordering rationale).
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

## Fail fast if M1-0 left any M1 mnemonic or DEFINE unexpanded (see
## step 08).
if grep -q 'sub_rdi\|lea_r9\|mov_rdi,rbp\|DWORD\|DEFINE' M1-macro-1.hex2; then
  echo "M1 hex2 contains untranslated M1 tokens" >&2
  exit 1
fi

## --base-address 0x600000 matches the __TEXT vmaddr in the lowdata
## template, so hex2-1 resolves labels to their run-time addresses.
hex2-1 \
  --architecture amd64 \
  --little-endian \
  --base-address 0x600000 \
  -f "$src/M2libc/amd64/MACHO-amd64-lowdata.hex2" \
  -f M1-macro-1.hex2 \
  -o M1

macho-patcher m2-segments M1-macro-1.hex2 M1

## Pad to the 0x2800000 __LINKEDIT file offset (see step 05).
dd if=/dev/zero of=M1 bs=1 count=1 seek=41943039 conv=notrunc 2>/dev/null || true
chmod +x M1
install M1 "$TARGET/bin/M1"

## Smoke test: usage text may land on stdout or stderr; check both.
"$TARGET/bin/M1" --help > help.stdout 2> help.stderr
cat help.stdout help.stderr > help.combined
grep -q 'Usage:' help.combined
