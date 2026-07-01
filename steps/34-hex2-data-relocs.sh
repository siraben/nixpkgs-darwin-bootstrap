#!/bin/sh
## 34-hex2-data-relocs — build the data-relocs post-link patcher.
##
## hex2 lays out code and data contiguously; Darwin maps __TEXT and
## __DATA as separate segments, so references into data need fixing
## after the link.  macho-patcher's m2-segments mode finds sites by
## scanning the binary for RIP-relative opcode patterns;
## hex2-data-relocs instead patches exactly the % (relative) and &
## (absolute) reference sites recorded in the .hex2 source.  The
## tcc-self link (step 35) and all later tcc links use this
## source-driven patcher.
##
## Built with the M2-Planet pipeline: M2-darwin compiles the C source
## to M1 against M2libc, M1 assembles with the full-Darwin libc
## macros, hex2 links, macho-patcher fixes segments.
##
## Runs:     M2-darwin (built in step 08), M1 (step 12), hex2 (step
##           13), macho-patcher (step 06); Apple /usr/bin dd/chmod/
##           install for orchestration.
## Inputs:   sources/bootstrap-c/hex2-data-relocs.c (committed C),
##           sources/stage0-posix/M2libc/ (headers, amd64 M1 defs,
##           libc-full-Darwin.M1, MACHO-amd64-lowdata.hex2).
## Outputs:  target/bin/hex2-data-relocs.
## Verifies: nothing here; step 35's tcc-self smoke run exercises it.
## Trust:    none beyond prior chain outputs.
set -eu

work="$TARGET/work/hex2-data-relocs"
rm -rf "$work"
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
  -f "$SOURCES/bootstrap-c/hex2-data-relocs.c" \
  -o hex2-data-relocs.M1

M1 --architecture amd64 --little-endian \
  -f "$src/M2libc/amd64/amd64_defs.M1" \
  -f "$src/M2libc/amd64/libc-full-Darwin.M1" \
  -f hex2-data-relocs.M1 \
  -o hex2-data-relocs.hex2

hex2 --architecture amd64 --little-endian \
  --base-address 0x600000 \
  -f "$src/M2libc/amd64/MACHO-amd64-lowdata.hex2" \
  -f hex2-data-relocs.hex2 \
  -o hex2-data-relocs

macho-patcher m2-segments hex2-data-relocs.hex2 hex2-data-relocs

## Pad to 0x2800000 (40 MiB), the fixed template's declared extent.
dd if=/dev/zero of=hex2-data-relocs bs=1 count=1 seek=41943039 conv=notrunc 2>/dev/null || true
chmod +x hex2-data-relocs
install hex2-data-relocs "$TARGET/bin/hex2-data-relocs"
