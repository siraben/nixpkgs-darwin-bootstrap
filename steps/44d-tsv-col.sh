#!/bin/sh
## 44d-tsv-col — compile the D/U symbol-table column extractor from
## C.
##
## tcc-darwin-cc's archive resolution builds defined/undefined symbol
## sets from elf64-to-m1 --symbols TSVs.  tsv-col replaces host awk
## (`awk -F'\t' '$1=="D"&&$2!=""{print $2}'`) for that
## symbol-selection step of the link path; it is verified to produce
## the same symbol set (the caller pipes the output to `sort -u`, so
## only the set matters).  The wrapper prefers $TARGET/bin/tsv-col
## and falls back to awk only while the binary is absent.  Built
## after 44c, before the first gcc archive (step 48).
##
## Runs:     tcc-darwin-cc (installed in step 44); Apple /usr/bin
##           chmod/printf for orchestration and checks.
## Inputs:   sources/tools/tsv-col.c.
## Outputs:  target/bin/tsv-col.
## Verifies: smoke test — tag-D and tag-U extraction on a fixture
##           TSV, including the skip of empty column 2 and of
##           unmatched tags.
## Trust:    this step's own link still runs the host-awk fallbacks
##           for tsv-col, ctor-table, line-rewrite and synth-inject;
##           the M1 split already uses chain m1-split (44c).
set -eu

"$TARGET/bin/tcc-darwin-cc" "$SOURCES/tools/tsv-col.c" -o "$TARGET/bin/tsv-col"
chmod +x "$TARGET/bin/tsv-col"
test -x "$TARGET/bin/tsv-col" || { echo "44d: tsv-col not built" >&2; exit 1; }

## Smoke test.
tmp="$TARGET/work/tsv-col-smoke"
rm -rf "$tmp"; mkdir -p "$tmp"
printf 'D\tsymA\nU\tsymB\nD\t\nX\tsymC\nD\tsymD\n' > "$tmp/in.tsv"
[ "$("$TARGET/bin/tsv-col" D < "$tmp/in.tsv")" = "$(printf 'symA\nsymD')" ] \
  && [ "$("$TARGET/bin/tsv-col" U < "$tmp/in.tsv")" = "symB" ] \
  || { echo "44d: tsv-col smoke test failed" >&2; exit 1; }
rm -rf "$tmp"

echo "tsv-col built at $TARGET/bin/tsv-col (chain-built; symbol-set awk retired)"
