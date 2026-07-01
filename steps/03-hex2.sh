#!/bin/sh
## 03-hex2 — assemble the phase-0 hex2 from its hand-written hex0 source.
##
## hex2-darwin reads hex plus label definitions (:name) and label
## references and resolves them to addresses, so later bodies (catm,
## M0, cc_arch, M2) can be written as relocatable hex2 text.  It takes
## a single input file and a fixed load layout; the flag-driven hex2
## linker arrives in steps 11 and 13.  Its Mach-O header gives __DATA
## 16 MiB (per the .hex0 layout notes: room for its label table).
##
## Runs:     hex0 (step 01, the seed); Apple dd, chmod, cp.
## Inputs:   sources/hex2_AMD64_darwin.hex0.
## Outputs:  target/bin/hex2-darwin,
##           target/share/hex2_AMD64_darwin.hex0.
## Verifies: nothing beyond hex0's exit status (set -e).
## Trust:    translation by the seed-built hex0.  Apple dd appends
##           content-free zero padding; /bin/sh orchestrates.
set -eu

hex0 "$SOURCES/hex2_AMD64_darwin.hex0" "$TARGET/bin/hex2-darwin"
## One zero byte at offset 0x17FFFFF grows the file to 0x1800000 bytes,
## the __LINKEDIT file offset declared in the embedded Mach-O header.
dd if=/dev/zero of="$TARGET/bin/hex2-darwin" bs=1 count=1 seek=25165823 conv=notrunc
chmod +x "$TARGET/bin/hex2-darwin"
cp "$SOURCES/hex2_AMD64_darwin.hex0" "$TARGET/share/"
