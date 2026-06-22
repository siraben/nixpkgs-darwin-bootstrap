#!/bin/sh
## 02-hex1 — assemble hex1 from its hex0 source via the seed-built hex0, then
## pad to the LINKEDIT vmaddr (0x1000000).  The .hex0 source is genuine
## machine-code source; the padding is applied here, not baked in.
set -eu

hex0 "$SOURCES/hex1_AMD64_darwin.hex0" "$TARGET/bin/hex1-darwin"
dd if=/dev/zero of="$TARGET/bin/hex1-darwin" bs=1 count=1 seek=16777215 conv=notrunc
chmod +x "$TARGET/bin/hex1-darwin"
cp "$SOURCES/hex1_AMD64_darwin.hex0" "$TARGET/share/"
