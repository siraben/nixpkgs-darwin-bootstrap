#!/bin/sh
## 44g-synth-inject — compile the cross-object synth-label injector from C.
##
## After flattening the combined link to one token per line, tcc-darwin-cc
## injects `:<sym>_plus_<hex>` definitions for cross-object references that
## elf64-to-m1 left undefined (e.g. C++ vtable slots), so hex2 resolves them.
## That was host awk (synth-inject.awk) — the most load-bearing host awk in the
## link path.  sources/tools/synth-inject.c is the chain-built replacement
## (3-pass fopen+rewind — freopen hangs in the chain libc; verified byte-
## identical to the awk).  Wrapper prefers $TARGET/bin/synth-inject, awk fallback
## only while bootstrapping it.  Built after 44f, before the first gcc archive.
set -eu

"$TARGET/bin/tcc-darwin-cc" "$SOURCES/tools/synth-inject.c" -o "$TARGET/bin/synth-inject"
chmod +x "$TARGET/bin/synth-inject"
test -x "$TARGET/bin/synth-inject" || { echo "44g: synth-inject not built" >&2; exit 1; }

## Smoke test: an undefined cross-object _plus_ ref injects a def at the right
## byte; output must match the awk.
tmp="$TARGET/work/synth-inject-smoke"
rm -rf "$tmp"; mkdir -p "$tmp"
printf ':mysym\n!0x01\n!0x02\n!0x03\n&mysym_plus_2>base\n' > "$tmp/in.M1"
awk -f "$SOURCES/tcc-darwin/synth-inject.awk" "$tmp/in.M1" > "$tmp/awk.out"
"$TARGET/bin/synth-inject" "$tmp/in.M1" > "$tmp/c.out"
cmp -s "$tmp/awk.out" "$tmp/c.out" \
  || { echo "44g: synth-inject smoke test differs from awk" >&2; exit 1; }
rm -rf "$tmp"

echo "synth-inject built at $TARGET/bin/synth-inject (chain-built; synth-inject awk retired)"
