#!/bin/sh
## 05-m0 — build M0, the minimal macro assembler.
##
## M0 expands DEFINE macros, mnemonics, and immediate forms in .M1
## text into a hex2 token stream.  From here on, hand-written tools
## (macho-patcher, step 06) and compiler output (cc_arch, M2) are M1
## text.  The body is committed hex2; catm (step 04) prepends the
## shared MACHO-amd64-lowdata header template, and hex2-darwin
## assembles the result.  Mirrors m0.nix.
##
## Runs:     catm-darwin (step 04), hex2-darwin (step 03); Apple dd,
##           chmod.
## Inputs:   sources/MACHO-amd64-lowdata.hex2,
##           sources/M0_AMD64_darwin_body.hex2.
## Outputs:  target/bin/M0-darwin.
## Verifies: nothing beyond the tools' exit statuses (set -e).
## Trust:    translation by chain-built catm + hex2-darwin.  Apple dd
##           appends content-free zero padding; /bin/sh orchestrates.
set -eu

work="$TARGET/work/m0"; mkdir -p "$work"; cd "$work"
catm-darwin M0-darwin.hex2 "$SOURCES/MACHO-amd64-lowdata.hex2" "$SOURCES/M0_AMD64_darwin_body.hex2"
hex2-darwin M0-darwin.hex2 "$TARGET/bin/M0-darwin"
## One zero byte at offset 0x27FFFFF grows the file to 0x2800000 bytes,
## the __LINKEDIT file offset in the lowdata template (__TEXT filesize
## 0x800000 + __DATA filesize 0x2000000).  Same pad target for every
## lowdata-template binary through step 21.
dd if=/dev/zero of="$TARGET/bin/M0-darwin" bs=1 count=1 seek=41943039 conv=notrunc
chmod +x "$TARGET/bin/M0-darwin"
