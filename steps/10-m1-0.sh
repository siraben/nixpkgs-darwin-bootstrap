#!/bin/sh
## 10-m1-0 — build M1-0, the first M1-macro.c assembler.
##
## M1-0 supersedes M0 for the assemblies that follow: it accepts
## multiple -f inputs, --architecture, and --little-endian, so defs,
## libc, and program text no longer need catm pre-concatenation.
## Steps 11 and 12 assemble with it.  Same pipeline as step 08:
## M2 (bootstrap-mode) → catm defs + libc-core + body → M0 →
## catm MACHO template + hex2 → hex2 → macho-patcher (see step 06) →
## pad.
##
## Runs:     M2-darwin (step 08), catm-darwin (step 04), M0-darwin
##           (step 05), hex2-darwin (step 03), macho-patcher (step
##           06); Apple dd, chmod, install, grep.
## Inputs:   sources/stage0-posix/mescc-tools/{stringify.c,
##           M1-macro.c}, M2libc/amd64/Darwin/bootstrap.c,
##           M2libc/bootstrappable.c, M2libc/amd64/{amd64_defs.M1,
##           libc-core-Darwin.M1,MACHO-amd64-lowdata.hex2}.
## Outputs:  target/bin/M1-0.
## Verifies: grep for untranslated M1 tokens (see step 08); smoke
##           test — --help prints a Usage line on stderr.
## Trust:    translation and layout by chain-built tools.  Apple dd
##           appends content-free zero padding; /bin/sh orchestrates.
set -eu

work="$TARGET/work/m1-0"
mkdir -p "$work"
cd "$work"

src="$SOURCES/stage0-posix"

## --bootstrap-mode: M2 targets the bootstrap.c libc (no full M2libc).
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

## Fail fast if M0 left any M1 mnemonic or DEFINE unexpanded (see
## step 08).
if grep -q 'sub_rdi\|lea_r9\|mov_rdi,rbp\|DWORD\|DEFINE' M1-0.hex2; then
  echo "M1-0 hex2 contains untranslated M1 tokens" >&2
  exit 1
fi

catm-darwin M1-0-0.hex2 \
  "$src/M2libc/amd64/MACHO-amd64-lowdata.hex2" \
  M1-0.hex2

hex2-darwin M1-0-0.hex2 M1-0
macho-patcher m2-segments M1-0.hex2 M1-0

## Pad to the 0x2800000 __LINKEDIT file offset (see step 05).
dd if=/dev/zero of=M1-0 bs=1 count=1 seek=41943039 conv=notrunc 2>/dev/null || true
chmod +x M1-0
install M1-0 "$TARGET/bin/M1-0"

## Smoke test: M1-0 writes its usage text to stderr.
"$TARGET/bin/M1-0" --help > help.stdout 2> help.stderr
grep -q 'Usage:' help.stderr
