#!/bin/sh
## 44f-line-rewrite — compile the template line-rewriter from C.
##
## tcc-darwin-cc builds each link's Mach-O load-command block by
## rewriting 8 size/offset lines of MACHO-amd64-lowdata.hex2 (lines
## 10,11,15,19,20,21,24,25 — the per-link segment layout from
## m1-to-hex2 --auto-data-align).  line-rewrite replaces host awk
## (NR==... field substitution) for that binary-layout step; it is
## generic — stdin template + `lineno replacement` argument pairs —
## and verified byte-identical to the awk on the real template.  The
## wrapper prefers $TARGET/bin/line-rewrite and falls back to awk
## only while the binary is absent.  Built after 44e, before the
## first gcc archive (step 48).
##
## Runs:     tcc-darwin-cc (installed in step 44); Apple /usr/bin
##           chmod/printf for orchestration and checks.
## Inputs:   sources/tools/line-rewrite.c.
## Outputs:  target/bin/line-rewrite.
## Verifies: smoke test — replace line 2 of a 3-line input, keep the
##           rest.
## Trust:    this step's own link still runs the host fallbacks for
##           line-rewrite and synth-inject; m1-split (44c), tsv-col
##           (44d) and ctor-table (44e) are chain tools already.
set -eu

"$TARGET/bin/tcc-darwin-cc" "$SOURCES/tools/line-rewrite.c" -o "$TARGET/bin/line-rewrite"
chmod +x "$TARGET/bin/line-rewrite"
test -x "$TARGET/bin/line-rewrite" || { echo "44f: line-rewrite not built" >&2; exit 1; }

## Smoke test: replace line 2, keep the rest.
tmp="$TARGET/work/line-rewrite-smoke"
rm -rf "$tmp"; mkdir -p "$tmp"
printf 'a\nb\nc\n' > "$tmp/in"
[ "$("$TARGET/bin/line-rewrite" 2 'XX' < "$tmp/in")" = "$(printf 'a\nXX\nc')" ] \
  || { echo "44f: line-rewrite smoke test failed" >&2; exit 1; }
rm -rf "$tmp"

echo "line-rewrite built at $TARGET/bin/line-rewrite (chain-built; Mach-O template awk retired)"
