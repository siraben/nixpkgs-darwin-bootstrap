#!/bin/sh
## 07-cc-arch — assemble cc_arch via hex0.
## The combined source bakes in catm(MACHO_template, cc_arch-0.hex2)
## followed by post-macho-patcher segment vmsize fixups and pad to
## 0x2800000.  hex0 produces the binary in one shot.
set -eu

hex0 "$SOURCES/cc_arch_AMD64_darwin_final.hex0" "$TARGET/bin/cc_arch-darwin"
chmod +x "$TARGET/bin/cc_arch-darwin"
cp "$SOURCES/cc_arch_AMD64_darwin_final.hex0" "$TARGET/share/"

## Smoke test
cc_arch-darwin > /tmp/bake-cc-arch-out 2>&1
grep -q '^# Core program$' /tmp/bake-cc-arch-out
grep -q '^# Program global variables$' /tmp/bake-cc-arch-out
rm -f /tmp/bake-cc-arch-out
