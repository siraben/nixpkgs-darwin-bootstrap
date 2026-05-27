#!/bin/sh
## 04-catm — assemble catm via hex2.
## Combined source = MACHO-amd64-catm-header.hex2 + catm body; padded to
## data_end=0x900000.
set -eu

hex2-darwin "$SOURCES/catm_AMD64_darwin_combined.hex2" "$TARGET/bin/catm-darwin"
chmod +x "$TARGET/bin/catm-darwin"
cp "$SOURCES/catm_AMD64_darwin_combined.hex2" "$TARGET/share/"

## Smoke test
echo foo > /tmp/bake-catm-a
echo bar > /tmp/bake-catm-b
catm-darwin /tmp/bake-catm-out /tmp/bake-catm-a /tmp/bake-catm-b
printf 'foo\nbar\n' > /tmp/bake-catm-expected
cmp /tmp/bake-catm-expected /tmp/bake-catm-out
rm -f /tmp/bake-catm-a /tmp/bake-catm-b /tmp/bake-catm-out /tmp/bake-catm-expected
