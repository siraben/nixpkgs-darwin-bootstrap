#!/bin/sh
## 02-hex1 — assemble hex1 via target/bin/hex0.
## Padding (to LINKEDIT vmaddr 0x1000000) is baked into the .hex0 source.
set -eu

hex0 "$SOURCES/hex1_AMD64_darwin.hex0" "$TARGET/bin/hex1-darwin"
chmod +x "$TARGET/bin/hex1-darwin"
cp "$SOURCES/hex1_AMD64_darwin.hex0" "$TARGET/share/"
