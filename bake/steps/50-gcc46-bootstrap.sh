#!/bin/sh
## 50-gcc46-bootstrap — final gcc-4.6 bootstrap (installable gcc 4.6).
set -eu

out="$TARGET/gcc46-bootstrap"
rm -rf "$out"
mkdir -p "$out"

/bin/bash "$SOURCES/gcc46-scripts/phase37-driver.sh" \
    "$TARGET/gcc46-all-gcc" \
    "$TARGET/gcc46-libgcc" \
    "$TARGET/tcc-darwin-cc-root" \
    "$SOURCES/gcc46-scripts/phase36-bootstrap-as.awk" \
    "" \
    "$TARGET/bin/elf64-to-m1" \
    "$out" \
    4.6.4
