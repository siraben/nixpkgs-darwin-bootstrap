#!/bin/sh
## 49-gcc46-libgcc — build libgcc using xgcc + cc1 from phase 48.
## Mirrors gcc-4.6/libgcc.nix which just calls scripts/gcc46/phase36-libgcc.sh.
set -eu

phase35="$TARGET/gcc46-all-gcc"
test -d "$phase35" || { echo "missing $phase35 (run 48-gcc46-all-gcc first)" >&2; exit 1; }

out="$TARGET/gcc46-libgcc"
rm -rf "$out"
mkdir -p "$out"

/bin/bash "$SOURCES/gcc46-scripts/phase36-libgcc.sh" \
    "$phase35" \
    "$TARGET/tcc-darwin-cc-root" \
    /usr/bin \
    /usr/bin/perl \
    "$SOURCES/gcc46-scripts/phase36-libgcc.pl" \
    "$SOURCES/gcc46-scripts/phase36-bootstrap-as.awk" \
    "$out" \
    4.6.4 \
    "$SOURCES/gcc46-scripts/phase36-xgcc-wrapper.sh"
