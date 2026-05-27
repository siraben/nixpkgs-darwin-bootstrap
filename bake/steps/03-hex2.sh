#!/bin/sh
## 03-hex2 — assemble hex2 via hex0.
## Padding to 0x1800000 baked into source.
set -eu

hex0 "$SOURCES/hex2_AMD64_darwin.hex0" "$TARGET/bin/hex2-darwin"
chmod +x "$TARGET/bin/hex2-darwin"
cp "$SOURCES/hex2_AMD64_darwin.hex0" "$TARGET/share/"
