#!/bin/sh
## 44c-m1-split — compile the M1 code/data section splitter from C.
##
## The tcc-darwin-cc link path splits each object/member's M1 into its code
## (before :ELF_data) and data (after) sections.  That was host awk in the
## active link path; sources/tools/m1-split.c is the chain-built replacement
## (verified byte-identical to the awk).  The wrapper prefers $TARGET/bin/
## m1-split and only falls back to awk while m1-split itself is being built here
## (its binary not yet present) — so this self-build is the LAST awk split; every
## subsequent gcc link uses chain-built C.  Built after 44b (bake-ar) so the
## whole gcc toolchain (steps 45+) has it.
set -eu

"$TARGET/bin/tcc-darwin-cc" "$SOURCES/tools/m1-split.c" -o "$TARGET/bin/m1-split"
chmod +x "$TARGET/bin/m1-split"
test -x "$TARGET/bin/m1-split" || { echo "44c: m1-split not built" >&2; exit 1; }

## Smoke test: a tiny combined M1 must split into the right sections.
tmp="$TARGET/work/m1-split-smoke"
rm -rf "$tmp"; mkdir -p "$tmp"
printf 'CODE1\n:HEX2_data\nCODE2\n:ELF_data\nDATA1\nDATA2\n' > "$tmp/in.M1"
[ "$("$TARGET/bin/m1-split" --code < "$tmp/in.M1")" = "$(printf 'CODE1\nCODE2')" ] \
  && [ "$("$TARGET/bin/m1-split" --data < "$tmp/in.M1")" = "$(printf 'DATA1\nDATA2')" ] \
  || { echo "44c: m1-split smoke test failed" >&2; exit 1; }
rm -rf "$tmp"

echo "m1-split built at $TARGET/bin/m1-split (chain-built; awk split retired)"
