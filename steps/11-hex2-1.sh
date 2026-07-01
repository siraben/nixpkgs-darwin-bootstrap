#!/bin/sh
## 11-hex2-1 — build hex2-1, the first hex2 with linker features,
## compiled from the mescc-tools hex2_linker sources.
##
## hex2-1 accepts multiple -f inputs and --base-address, so from step
## 12 on the Mach-O header template and program text link in one
## invocation at a chosen load address.  The compile uses the full
## M2libc file list (M2-darwin without --bootstrap-mode) and links
## against libc-full-Darwin.M1; M1-0 (step 10) assembles.  Final step
## that links with the single-input hex2-darwin, which requires the
## catm template+body concatenation.
##
## Runs:     M2-darwin (step 08), M1-0 (step 10), catm-darwin (step
##           04), hex2-darwin (step 03), macho-patcher (step 06);
##           Apple dd, chmod, install, grep, cat.
## Inputs:   sources/stage0-posix/mescc-tools/{hex2.h,hex2_linker.c,
##           hex2_word.c,hex2.c}, M2libc headers and libc .c files
##           (listed below), M2libc/amd64/{amd64_defs.M1,
##           libc-full-Darwin.M1,MACHO-amd64-lowdata.hex2}.
## Outputs:  target/bin/hex2-1.
## Verifies: grep for untranslated M1 tokens (see step 08); smoke
##           test — --help output contains a Usage line.
## Trust:    translation and layout by chain-built tools.  Apple dd
##           appends content-free zero padding; /bin/sh orchestrates.
set -eu

work="$TARGET/work/hex2-1"
mkdir -p "$work"
cd "$work"

src="$SOURCES/stage0-posix"

## Full M2libc build: headers first, then the Darwin syscall layers,
## then portable libc, then the program.  Single-pass compilation
## needs declarations before use.
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

## Fail fast if M1-0 left any M1 mnemonic or DEFINE unexpanded (see
## step 08).
if grep -q 'sub_rdi\|lea_r9\|mov_rdi,rbp\|DWORD\|DEFINE' hex2_linker-0.hex2; then
  echo "hex2-1 hex2 contains untranslated M1 tokens" >&2
  exit 1
fi

catm-darwin hex2-1-0.hex2 \
  "$src/M2libc/amd64/MACHO-amd64-lowdata.hex2" \
  hex2_linker-0.hex2

hex2-darwin hex2-1-0.hex2 hex2-1
macho-patcher m2-segments hex2_linker-0.hex2 hex2-1

## Pad to the 0x2800000 __LINKEDIT file offset (see step 05).
dd if=/dev/zero of=hex2-1 bs=1 count=1 seek=41943039 conv=notrunc 2>/dev/null || true
chmod +x hex2-1
install hex2-1 "$TARGET/bin/hex2-1"

## Smoke test: usage text may land on stdout or stderr; check both.
"$TARGET/bin/hex2-1" --help > help.stdout 2> help.stderr
cat help.stdout help.stderr > help.combined
grep -q 'Usage:' help.combined
