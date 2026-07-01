#!/bin/sh
## 03-hex2 — assemble hex2 from its hex0 source via hex0, pad to 0x1800000.
set -eu

hex0 "$SOURCES/hex2_AMD64_darwin.hex0" "$TARGET/bin/hex2-darwin"
dd if=/dev/zero of="$TARGET/bin/hex2-darwin" bs=1 count=1 seek=25165823 conv=notrunc
chmod +x "$TARGET/bin/hex2-darwin"
cp "$SOURCES/hex2_AMD64_darwin.hex0" "$TARGET/share/"
