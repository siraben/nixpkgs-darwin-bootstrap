#!/bin/sh
## 08-m2 — build the bootstrap M2-Planet (M2-darwin), the first C
## compiler in the chain compiled from C source.
##
## First "real build" step: cc_arch (step 07) compiles the M2-Planet
## C sources, M0 expands the resulting .M1, hex2 assembles, and
## macho-patcher applies the m2-segments fixup (see step 06).
## M2-darwin compiles the rest of the mescc-tools suite (steps 09-14)
## and the full M2-Planet (step 16).  Steps 09-10 pass it
## --bootstrap-mode; it accepts multiple -f inputs, so catm
## concatenation of C sources ends here.
##
## Runs:     catm-darwin (step 04), cc_arch-darwin (step 07),
##           M0-darwin (step 05), hex2-darwin (step 03),
##           macho-patcher (step 06); Apple dd, chmod, install, grep;
##           the fresh M2-darwin for its own smoke tests.
## Inputs:   sources/stage0-posix/M2-Planet/*.c + cc.h,
##           sources/stage0-posix/M2libc/amd64/Darwin/bootstrap.c,
##           M2libc/bootstrappable.c, M2libc/amd64/amd64_defs.M1,
##           M2libc/amd64/libc-core-Darwin.M1,
##           M2libc/amd64/MACHO-amd64-lowdata.hex2.
## Outputs:  target/bin/M2-darwin.
## Verifies: (a) grep for untranslated M1 tokens in the hex2 stream —
##           leftover mnemonics or DEFINE lines mean M0 missed a
##           macro, which would otherwise surface as a corrupt binary;
##           (b) smoke tests — the no-input error message and the
##           --help usage text.
## Trust:    translation and layout by chain-built tools.  Apple dd
##           appends content-free zero padding; grep only checks;
##           /bin/sh orchestrates.
set -eu

work="$TARGET/work/m2"
mkdir -p "$work"
cd "$work"

src="$SOURCES/stage0-posix"

## 1) Concatenate the 10 C input files into a single source —
##    cc_arch reads exactly one input file.  Order matters for a
##    single-pass compiler: bootstrap.c (the bootstrap-mode libc
##    declarations and functions) first, cc.c (main) last.
catm-darwin M2-0.c \
  "$src/M2libc/amd64/Darwin/bootstrap.c" \
  "$src/M2-Planet/cc.h" \
  "$src/M2libc/bootstrappable.c" \
  "$src/M2-Planet/cc_globals.c" \
  "$src/M2-Planet/cc_reader.c" \
  "$src/M2-Planet/cc_strings.c" \
  "$src/M2-Planet/cc_types.c" \
  "$src/M2-Planet/cc_emit.c" \
  "$src/M2-Planet/cc_core.c" \
  "$src/M2-Planet/cc_macro.c" \
  "$src/M2-Planet/cc.c"

## 2) cc_arch compiles to .M1.
cc_arch-darwin M2-0.c M2-0.M1

## 3) Concatenate amd64_defs.M1 + libc-core-Darwin.M1 + cc_arch output.
##    amd64_defs.M1 supplies the DEFINE macros M0 expands;
##    libc-core-Darwin.M1 supplies :_start and the low-level runtime
##    the compiled code calls.
catm-darwin M2-0-0.M1 \
  "$src/M2libc/amd64/amd64_defs.M1" \
  "$src/M2libc/amd64/libc-core-Darwin.M1" \
  M2-0.M1

## 4) M0 expands macros into a hex2 token stream.
M0-darwin M2-0-0.M1 M2-0.hex2

## Any M1 mnemonic or DEFINE line surviving into the hex2 stream means
## macro expansion missed a token; fail here with a clear message.
if grep -q 'sub_rdi\|lea_r9\|DWORD\|DEFINE' M2-0.hex2; then
  echo "M2 hex2 contains untranslated M1 tokens" >&2
  exit 1
fi

## 5) Concatenate MACHO header template + body.
catm-darwin M2-0-0.hex2 \
  "$src/M2libc/amd64/MACHO-amd64-lowdata.hex2" \
  M2-0.hex2

## 6) hex2 links into a Mach-O binary.
hex2-darwin M2-0-0.hex2 M2-darwin

## 7) macho-patcher fixes segment layout in place (see step 06);
##    it reads the body hex2 (without the header template) to find
##    the first data label.
macho-patcher m2-segments M2-0.hex2 M2-darwin

## 8) Pad to LINKEDIT offset 0x2800000 = 41943040 with dd (one zero
##    byte written at target_size - 1; see step 05).
target_size=41943040
dd if=/dev/zero of=M2-darwin bs=1 count=1 \
  seek=$((target_size - 1)) conv=notrunc 2>/dev/null || true

chmod +x M2-darwin
install M2-darwin "$TARGET/bin/M2-darwin"

## Smoke test
"$TARGET/bin/M2-darwin" > "$TARGET/work/m2-noinput.stderr" 2>&1 || true
grep -q 'Either no input files were given' "$TARGET/work/m2-noinput.stderr"
"$TARGET/bin/M2-darwin" --help > "$TARGET/work/m2-help.stdout" 2>&1
grep -q 'Usage: M2-Planet' "$TARGET/work/m2-help.stdout"
