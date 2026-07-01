#!/bin/sh
## 30-elf64-to-m1 — assemble the ELF-to-M1 converter.
##
## tcc emits ELF64 relocatable objects (step 28) and the chain's only
## linker is hex2, which consumes M1/hex2 text.  elf64-to-m1 bridges
## the two: it translates an ELF .o (symbols, relocations, .text/
## .data/.bss) into M1 source, enabling the "ELF-object detour" every
## later tcc link uses — tcc -c → elf64-to-m1 → M1 → hex2 → Mach-O.
## The tool itself is hand-written M1 (see the header comment in
## sources/tools/elf64-to-m1.M1 for the full format contract).
##
## Runs:     M1 (built in step 12), hex2 (step 13); Apple /usr/bin
##           dd/chmod/install for orchestration.
## Inputs:   sources/tools/elf64-to-m1.M1 (committed hand-written
##           source), sources/stage0-posix/M2libc/amd64/amd64_defs.M1
##           (instruction macros), MACHO-amd64.hex2 (load-command
##           template).
## Outputs:  target/bin/elf64-to-m1.
## Verifies: nothing here; steps 31–32 exercise the converter.
## Trust:    none beyond prior chain outputs.
set -eu

work="$TARGET/work/elf64-to-m1"
rm -rf "$work"
mkdir -p "$work"
cd "$work"

src="$SOURCES/stage0-posix"

M1 \
  --architecture amd64 \
  --little-endian \
  -f "$src/M2libc/amd64/amd64_defs.M1" \
  -f "$SOURCES/tools/elf64-to-m1.M1" \
  -o elf64-to-m1.hex2

## MACHO-amd64.hex2 maps one __TEXT segment covering code and data,
## so no post-link macho-patcher segment pass is needed (the lowdata
## template used elsewhere splits __TEXT/__DATA and requires one).
hex2 \
  --architecture amd64 \
  --little-endian \
  --base-address 0x1000000 \
  -f "$src/M2libc/amd64/MACHO-amd64.hex2" \
  -f elf64-to-m1.hex2 \
  -o elf64-to-m1

## Pad the file to 0x2800000 (40 MiB) — the extent declared by the
## fixed Mach-O template's load commands.
dd if=/dev/zero of=elf64-to-m1 bs=1 count=1 seek=41943039 conv=notrunc 2>/dev/null || true
chmod +x elf64-to-m1
install elf64-to-m1 "$TARGET/bin/elf64-to-m1"
