#!/bin/sh
## 06-macho-patcher-early — build macho-patcher, the post-hex2 Mach-O
## segment fixup tool.  Mirrors macho-patcher-early.nix.
##
## hex2-darwin writes static data straight after the code in the file,
## while the lowdata Mach-O header maps __DATA at file offset 0x800000
## / vmaddr 0xE00000.  `macho-patcher m2-segments SOURCE.hex2 BINARY`
## (used by steps 07-21) reads the hex2 source to locate the first
## data label (:ELF_data / :HEX2_data / :GLOBAL_* / :STRING_*), copies
## the data from its post-code offset to 0x800000, and rewrites
## RIP-rel32 displacements to target 0xE00000 (see the header of
## sources/macho-patcher-m0.M1).  Cycle-breaker: the tool is written
## in M1 and assembled with M0 + hex2-darwin alone.  Its own binary
## uses the MACHO-amd64.hex2 template, whose single __TEXT segment
## spans the whole file with no __DATA segment, so data stays where
## hex2-darwin wrote it and no segment fixup is needed.
##
## Runs:     catm-darwin (step 04), M0-darwin (step 05), hex2-darwin
##           (step 03); Apple dd, chmod.
## Inputs:   sources/amd64_defs.M1, sources/amd64_byte_defs.M1
##           (macro definitions), sources/macho-patcher-m0.M1 (body),
##           sources/MACHO-amd64.hex2 (header template).
## Outputs:  target/bin/macho-patcher.
## Verifies: nothing beyond the tools' exit statuses (set -e).
## Trust:    translation by chain-built catm + M0 + hex2-darwin.
##           Apple dd appends content-free zero padding; /bin/sh
##           orchestrates.
set -eu

work="$TARGET/work/mpe"; mkdir -p "$work"; cd "$work"
catm-darwin combined.M0 \
  "$SOURCES/amd64_defs.M1" \
  "$SOURCES/amd64_byte_defs.M1" \
  "$SOURCES/macho-patcher-m0.M1"
M0-darwin combined.M0 combined.hex2
catm-darwin final.hex2 "$SOURCES/MACHO-amd64.hex2" combined.hex2
hex2-darwin final.hex2 "$TARGET/bin/macho-patcher"
## Pad to 0x2800000 bytes like the other chain binaries.  This
## template's __LINKEDIT sits at file offset 0x1000000, inside the
## padded extent.
dd if=/dev/zero of="$TARGET/bin/macho-patcher" bs=1 count=1 seek=41943039 conv=notrunc
chmod +x "$TARGET/bin/macho-patcher"
