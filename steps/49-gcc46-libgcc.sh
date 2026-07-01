#!/bin/sh
## 49-gcc46-libgcc — build libgcc using xgcc + cc1 from phase 48.
## Mirrors gcc-4.6/libgcc.nix which just calls scripts/gcc-4.6/libgcc.sh.
set -eu

phase35="$TARGET/gcc46-all-gcc"
test -d "$phase35" || { echo "missing $phase35 (run 48-gcc46-all-gcc first)" >&2; exit 1; }

out="$TARGET/gcc46-libgcc"
rm -rf "$out"
mkdir -p "$out"

## Use the ELF-capable bake-ar / no-op bake-ranlib (Apple's ar drops our
## ELF objects); phase36-libgcc.sh honors a pre-set AR/RANLIB.
export AR="$ROOT/scripts/bake-ar"
export RANLIB="$ROOT/scripts/bake-ranlib"
export LC_ALL=C LANG=C

/bin/bash "$SOURCES/gcc46-scripts/phase36-libgcc.sh" \
    "$phase35" \
    "$TARGET/tcc-darwin-cc-root" \
    /usr/bin \
    /usr/bin/perl \
    "$SOURCES/gcc46-scripts/phase36-libgcc.pl" \
    "$SOURCES/gcc46-scripts/phase36-bootstrap-as.c" \
    "$out" \
    4.6.4 \
    "$SOURCES/gcc46-scripts/phase36-xgcc-wrapper.sh"
