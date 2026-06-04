#!/bin/sh
## 44d-tsv-col — compile the D/U symbol-table column extractor from C.
##
## tcc-darwin-cc's archive resolution builds defined/undefined symbol sets from
## elf64-to-m1 --symbols TSVs.  Extracting column 2 by tag was host awk
## (`awk -F'\t' '$1=="D"&&$2!=""{print $2}'`) — semantically-significant symbol
## selection in the active link path.  sources/tools/tsv-col.c is the chain-built
## replacement (verified to produce the same symbol set; output is piped to
## `sort -u`).  The wrapper prefers $TARGET/bin/tsv-col, awk fallback only while
## bootstrapping it.  Built after 44c, before the first gcc archive (48).
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
