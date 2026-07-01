#!/bin/sh
## 44c-m1-split — compile the M1 code/data section splitter from C.
##
## The tcc-darwin-cc link path splits each object/member's M1 into
## its code (before :ELF_data) and data (after) sections.  m1-split
## replaces host awk for that split in the link path; its output is
## verified byte-identical to the awk program.  The wrapper prefers
## $TARGET/bin/m1-split and falls back to awk only while the binary
## is absent, so this self-build is the last link that uses the awk
## split; every link from step 44d on uses chain-built C.
##
## Runs:     tcc-darwin-cc (installed in step 44; this link itself
##           still uses the awk fallback for the split); Apple
##           /usr/bin chmod/printf for orchestration and checks.
## Inputs:   sources/tools/m1-split.c.
## Outputs:  target/bin/m1-split.
## Verifies: smoke test — a small combined M1 splits into the exact
##           expected code and data lines, with the :ELF_data and
##           :HEX2_data marker lines dropped from both.
## Trust:    host awk runs inside this step's tcc-darwin-cc link
##           (fallback path); the produced m1-split is chain code.
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
