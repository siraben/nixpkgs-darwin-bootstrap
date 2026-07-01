#!/bin/sh
## 44g-synth-inject — compile the cross-object synth-label injector
## from C.
##
## After flattening the combined link to one token per line,
## tcc-darwin-cc injects `:<sym>_plus_<hex>` definitions for
## cross-object references that elf64-to-m1 left undefined (e.g. C++
## vtable slots), so hex2 resolves them.  synth-inject replaces host
## awk (synth-inject.awk) — the symbol-resolution core of the link
## path.  The C implementation reads the input in three passes via
## fopen+rewind (freopen hangs in the chain libc) and is verified
## byte-identical to the awk.  The wrapper prefers $TARGET/bin/
## synth-inject and falls back to the awk only while the binary is
## absent.  Built after 44f, before the first gcc archive (step 48);
## from step 45 on the whole tcc-darwin-cc link path is chain-built C.
##
## Runs:     tcc-darwin-cc (installed in step 44); host awk runs the
##           reference synth-inject.awk in the smoke test; Apple
##           /usr/bin chmod/printf/cmp for orchestration and checks.
## Inputs:   sources/tools/synth-inject.c;
##           sources/tcc-darwin/synth-inject.awk (smoke reference).
## Outputs:  target/bin/synth-inject.
## Verifies: smoke test — a fixture with an undefined cross-object
##           `_plus_` reference; the C output must byte-match the awk
##           output (injected def lands at the correct byte).
## Trust:    this step's own link still runs the awk fallback for
##           synth-inject; every other link-path tool is chain-built
##           (44b–44f).
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
