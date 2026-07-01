#!/bin/sh
## 09-blood-elf-macho — build blood-macho-0, the debug-footer
## generator from mescc-tools (blood-elf) compiled for Darwin.
##
## blood-elf reads an .M1 file and emits a companion .M1 stub/footer
## for each label so debuggers can resolve symbols.  Pipeline mirrors
## the Nix recipe: M2 (bootstrap-mode) compiles → catm joins defs +
## libc-core + body → M0 expands → catm prepends the MACHO template →
## hex2 assembles → macho-patcher m2-segments fixup (see step 06) →
## pad.  mes's kaem.run invokes blood-elf after the point where the
## step 17 probe stops; no script under steps/ invokes blood-macho-0.
##
## Runs:     M2-darwin (step 08), catm-darwin (step 04), M0-darwin
##           (step 05), hex2-darwin (step 03), macho-patcher (step
##           06); Apple dd, chmod, install, grep.
## Inputs:   sources/stage0-posix/mescc-tools/{stringify.c,
##           blood-elf.c}, M2libc/amd64/Darwin/bootstrap.c,
##           M2libc/bootstrappable.c, M2libc/amd64/{amd64_defs.M1,
##           libc-core-Darwin.M1,MACHO-amd64-lowdata.hex2}.
## Outputs:  target/bin/blood-macho-0.
## Verifies: grep for untranslated M1 tokens in the hex2 stream (see
##           step 08).
## Trust:    translation and layout by chain-built tools.  Apple dd
##           appends content-free zero padding; /bin/sh orchestrates.
set -eu

work="$TARGET/work/blood-elf-macho"
mkdir -p "$work"
cd "$work"

src="$SOURCES/stage0-posix"

## --bootstrap-mode: M2 targets the bootstrap.c libc (no full M2libc).
M2-darwin \
  --architecture amd64 \
  -f "$src/M2libc/amd64/Darwin/bootstrap.c" \
  -f "$src/M2libc/bootstrappable.c" \
  -f "$src/mescc-tools/stringify.c" \
  -f "$src/mescc-tools/blood-elf.c" \
  --bootstrap-mode \
  -o blood-macho-0.M1

catm-darwin blood-macho-0-0.M1 \
  "$src/M2libc/amd64/amd64_defs.M1" \
  "$src/M2libc/amd64/libc-core-Darwin.M1" \
  blood-macho-0.M1

M0-darwin blood-macho-0-0.M1 blood-macho-0.hex2

## Fail fast if M0 left any M1 mnemonic or DEFINE unexpanded (see
## step 08).
if grep -q 'sub_rdi\|lea_r9\|mov_rdi,rbp\|DWORD\|DEFINE' blood-macho-0.hex2; then
  echo "blood-macho-0 hex2 contains untranslated M1 tokens" >&2
  exit 1
fi

catm-darwin blood-macho-0-0.hex2 \
  "$src/M2libc/amd64/MACHO-amd64-lowdata.hex2" \
  blood-macho-0.hex2

hex2-darwin blood-macho-0-0.hex2 blood-macho-0
macho-patcher m2-segments blood-macho-0.hex2 blood-macho-0

## Pad to the 0x2800000 __LINKEDIT file offset (see step 05).
target_size=41943040
dd if=/dev/zero of=blood-macho-0 bs=1 count=1 \
  seek=$((target_size - 1)) conv=notrunc 2>/dev/null || true

chmod +x blood-macho-0
install blood-macho-0 "$TARGET/bin/blood-macho-0"
