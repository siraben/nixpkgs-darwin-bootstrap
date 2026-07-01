#!/bin/sh
## 02-hex1 — assemble hex1 from its hand-written hex0 source.
##
## hex1 is the second rung of the stage0 ladder.  The .hex0 source is
## genuine machine-code source: a 1024-byte Mach-O header plus the
## Darwin-ported hex1 body, every byte commented (see the layout notes
## at the top of sources/hex1_AMD64_darwin.hex0).  No later step in
## steps/ invokes hex1-darwin; step 03 assembles hex2 from a .hex0
## source directly with hex0.
##
## Runs:     hex0 (step 01, the seed); Apple dd, chmod, cp.
## Inputs:   sources/hex1_AMD64_darwin.hex0.
## Outputs:  target/bin/hex1-darwin,
##           target/share/hex1_AMD64_darwin.hex0.
## Verifies: nothing beyond hex0's exit status (set -e).
## Trust:    translation by the seed-built hex0.  Apple dd appends
##           content-free zero padding; /bin/sh orchestrates.
set -eu

hex0 "$SOURCES/hex1_AMD64_darwin.hex0" "$TARGET/bin/hex1-darwin"
## dd writes one zero byte at offset 0xFFFFFF, growing the file to
## 0x1000000 bytes — the __LINKEDIT file offset declared in the
## embedded Mach-O header.  The padding is applied here at build time;
## the committed .hex0 source carries no filler bytes.
dd if=/dev/zero of="$TARGET/bin/hex1-darwin" bs=1 count=1 seek=16777215 conv=notrunc
chmod +x "$TARGET/bin/hex1-darwin"
cp "$SOURCES/hex1_AMD64_darwin.hex0" "$TARGET/share/"
