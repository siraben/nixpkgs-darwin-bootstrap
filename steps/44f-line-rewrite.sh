#!/bin/sh
## 44f-line-rewrite — compile the template line-rewriter from C.
##
## tcc-darwin-cc builds each link's Mach-O load-command block by rewriting 8
## size/offset lines of MACHO-amd64-lowdata.hex2 — that was host awk
## (NR==10..25 field substitution).  sources/tools/line-rewrite.c is the chain-
## built replacement (generic: stdin template + `lineno replacement` arg pairs;
## verified byte-identical to the awk on the real template).  Wrapper prefers
## $TARGET/bin/line-rewrite, awk fallback only while bootstrapping it.  Built
## after 44e, before the first gcc archive (48).
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
