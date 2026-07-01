#!/bin/sh
## 44e-ctor-table — compile the C++ global-constructor table emitter
## from C.
##
## gcc (configured x86_64-apple-darwin) registers each TU's
## global-ctor entry via a .mod_init_func pointer the as-filter/tcc
## chain drops, so tcc-darwin-cc rebuilds the init table by scanning
## the code M1s for `<prefix>_GLOBAL__sub_I` labels.  ctor-table
## replaces the host grep|sed|awk|while pipeline for that link-path
## step; its output is verified byte-identical, including cross-file
## dedup-in-order.  The wrapper prefers $TARGET/bin/ctor-table and
## falls back to the host pipeline only while the binary is absent.
## Built after 44d, before the first gcc archive (step 48).
##
## Runs:     tcc-darwin-cc (installed in step 44); Apple /usr/bin
##           chmod/printf for orchestration and checks.
## Inputs:   sources/tools/ctor-table.c.
## Outputs:  target/bin/ctor-table.
## Verifies: smoke test — dedup-in-order across two fixture files,
##           non-ctor labels ignored, missing files skipped.
## Trust:    this step's own link still runs the host fallbacks for
##           ctor-table, line-rewrite and synth-inject; m1-split
##           (44c) and tsv-col (44d) are chain tools already.
set -eu

"$TARGET/bin/tcc-darwin-cc" "$SOURCES/tools/ctor-table.c" -o "$TARGET/bin/ctor-table"
chmod +x "$TARGET/bin/ctor-table"
test -x "$TARGET/bin/ctor-table" || { echo "44e: ctor-table not built" >&2; exit 1; }

## Smoke test: dedup-in-order across files, ignore non-ctor lines.
tmp="$TARGET/work/ctor-table-smoke"
rm -rf "$tmp"; mkdir -p "$tmp"
printf ':_GLOBAL__sub_I_a\n:x\n:_GLOBAL__sub_I_a\n' > "$tmp/1.M1"
printf ':p_GLOBAL__sub_I_b junk\n' > "$tmp/2.M1"
exp="$(printf '&_GLOBAL__sub_I_a\n!0x00 !0x00 !0x00 !0x00\n&p_GLOBAL__sub_I_b\n!0x00 !0x00 !0x00 !0x00')"
[ "$("$TARGET/bin/ctor-table" "$tmp/1.M1" "$tmp/2.M1" "$tmp/missing.M1")" = "$exp" ] \
  || { echo "44e: ctor-table smoke test failed" >&2; exit 1; }
rm -rf "$tmp"

echo "ctor-table built at $TARGET/bin/ctor-table (chain-built; ctor-table awk retired)"
