#!/bin/sh
## 13-hex2-linker — build the final hex2 linker.
##
## Same hex2_linker sources as step 11, assembled by the full M1
## (step 12) and linked by hex2-1.  Installed as `hex2`, the linker
## name every downstream phase invokes: steps 14, 16, 18, 21, the
## mes/tinycc/gcc phases, and mescc via the HEX2 environment
## variable (steps 20-21).
##
## Runs:     M2-darwin (step 08), M1 (step 12), hex2-1 (step 11),
##           macho-patcher (step 06); Apple dd, chmod, install, grep,
##           cat.
## Inputs:   sources/stage0-posix/mescc-tools/{hex2.h,hex2_linker.c,
##           hex2_word.c,hex2.c}, M2libc headers and libc .c files
##           (listed below), M2libc/amd64/{amd64_defs.M1,
##           libc-full-Darwin.M1,MACHO-amd64-lowdata.hex2}.
## Outputs:  target/bin/hex2.
## Verifies: grep for untranslated M1 tokens (see step 08); smoke
##           test — --help output contains a Usage line.
## Trust:    translation and layout by chain-built tools.  Apple dd
##           appends content-free zero padding; /bin/sh orchestrates.
set -eu

work="$TARGET/work/hex2-linker"
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

## Fail fast if M1 left any M1 mnemonic or DEFINE unexpanded (see
## step 08).
if grep -q 'sub_rdi\|lea_r9\|mov_rdi,rbp\|DWORD\|DEFINE' hex2_linker-2.hex2; then
  echo "hex2-linker hex2 contains untranslated M1 tokens" >&2
  exit 1
fi

## --base-address 0x600000 = __TEXT vmaddr of the lowdata template
## (see step 12).
hex2-1 \
  --architecture amd64 \
  --little-endian \
  --base-address 0x600000 \
  -f "$src/M2libc/amd64/MACHO-amd64-lowdata.hex2" \
  -f hex2_linker-2.hex2 \
  -o hex2

macho-patcher m2-segments hex2_linker-2.hex2 hex2

## Pad to the 0x2800000 __LINKEDIT file offset (see step 05).
dd if=/dev/zero of=hex2 bs=1 count=1 seek=41943039 conv=notrunc 2>/dev/null || true
chmod +x hex2
install hex2 "$TARGET/bin/hex2"

## Smoke test: usage text may land on stdout or stderr; check both.
"$TARGET/bin/hex2" --help > help.stdout 2> help.stderr
cat help.stdout help.stderr > help.combined
grep -q 'Usage:' help.combined
