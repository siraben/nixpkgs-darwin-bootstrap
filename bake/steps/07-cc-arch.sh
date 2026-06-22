#!/bin/sh
## 07-cc-arch — catm(MACHO-lowdata, cc_arch-0 body) -> hex2 -> macho-patcher
## m2-segments vmsize fixup -> pad to 0x2800000.  Mirrors cc-arch.nix.
set -eu

work="$TARGET/work/cc-arch"; mkdir -p "$work"; cd "$work"
cp "$SOURCES/cc_arch-0-darwin.hex2" cc_arch-0.hex2
catm-darwin cc_arch.hex2 "$SOURCES/MACHO-amd64-lowdata.hex2" cc_arch-0.hex2
hex2-darwin cc_arch.hex2 "$TARGET/bin/cc_arch-darwin"
macho-patcher m2-segments cc_arch-0.hex2 "$TARGET/bin/cc_arch-darwin"
dd if=/dev/zero of="$TARGET/bin/cc_arch-darwin" bs=1 count=1 seek=41943039 conv=notrunc
chmod +x "$TARGET/bin/cc_arch-darwin"

## Smoke test
cc_arch-darwin > out 2>&1 || true
grep -q '^# Core program$' out
grep -q '^# Program global variables$' out
