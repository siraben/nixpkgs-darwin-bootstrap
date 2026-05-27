#!/bin/sh
## 05-m0 — assemble M0 via hex2.
## Combined source = MACHO-amd64-lowdata.hex2 + M0 body; padded to 0x2800000.
set -eu

hex2-darwin "$SOURCES/M0_AMD64_darwin_combined.hex2" "$TARGET/bin/M0-darwin"
chmod +x "$TARGET/bin/M0-darwin"
cp "$SOURCES/M0_AMD64_darwin_combined.hex2" "$TARGET/share/"
