#!/bin/sh
## 05-m0 — catm the MACHO header template + M0 body, assemble via hex2, pad to
## 0x2800000.  Mirrors m0.nix.
set -eu

work="$TARGET/work/m0"; mkdir -p "$work"; cd "$work"
catm-darwin M0-darwin.hex2 "$SOURCES/MACHO-amd64-lowdata.hex2" "$SOURCES/M0_AMD64_darwin_body.hex2"
hex2-darwin M0-darwin.hex2 "$TARGET/bin/M0-darwin"
dd if=/dev/zero of="$TARGET/bin/M0-darwin" bs=1 count=1 seek=41943039 conv=notrunc
chmod +x "$TARGET/bin/M0-darwin"
