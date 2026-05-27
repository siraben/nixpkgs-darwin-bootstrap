#!/bin/sh
## 06-macho-patcher-early — assemble macho-patcher via hex2.
## Source bakes in catm(MACHO_template, M0(catm(amd64_defs.M1,
## amd64_byte_defs.M1, macho-patcher-m0.M1))), padded to 0x2800000.
set -eu

hex2-darwin "$SOURCES/macho-patcher_AMD64_darwin_combined.hex2" \
  "$TARGET/bin/macho-patcher"
chmod +x "$TARGET/bin/macho-patcher"
cp "$SOURCES/macho-patcher_AMD64_darwin_combined.hex2" "$TARGET/share/"
