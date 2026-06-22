#!/bin/sh
## 04-catm — assemble catm: hex2 the Mach-O header template and the catm body
## separately, concatenate, pad to data_end (0x900000).  Mirrors catm.nix.
set -eu

work="$TARGET/work/catm"; mkdir -p "$work"; cd "$work"
hex2-darwin "$SOURCES/MACHO-amd64-catm-header.hex2" header.bin
hex2-darwin "$SOURCES/catm_AMD64_darwin_body.hex2" body.bin
cat header.bin body.bin > "$TARGET/bin/catm-darwin"

dataEnd=9437184  ## 0x900000
cur=$(wc -c < "$TARGET/bin/catm-darwin")
if [ "$cur" -lt "$dataEnd" ]; then
  dd if=/dev/zero of="$TARGET/bin/catm-darwin" bs=1 count=$((dataEnd - cur)) seek="$cur" conv=notrunc 2>/dev/null
fi
chmod +x "$TARGET/bin/catm-darwin"

## Smoke test
echo foo > a; echo bar > b
catm-darwin out a b
printf 'foo\nbar\n' > expected
cmp expected out
