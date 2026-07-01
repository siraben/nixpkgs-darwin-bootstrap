#!/bin/sh
## 50-gcc46-bootstrap — final gcc-4.6 bootstrap (installable gcc 4.6).
##
## Assembles a self-contained gcc-4.6 install tree from the pieces built
## in steps 48 (xgcc/cc1/cpp) and 49 (libgcc), with a `gcc` driver
## wrapper that runs cc1 + the bootstrap-as filter + tcc-darwin-cc for
## assembly and linking.  This is the chain's first complete optimizing
## C compiler installation.
##
## Runs:    phase37-driver.sh (symlink to nix/scripts/gcc-4.6/driver.sh,
##          bash), which compiles the bootstrap-as filter from
##          phase36-bootstrap-as.c with the chain tcc-darwin-cc, merges
##          the gcc and tcc-bootstrap include trees, writes the driver
##          wrapper, and runs smoke tests.  Arg 5 is empty (legacy
##          python slot; the chain has no python); arg 6 is the chain
##          elf64-to-m1.
## Inputs:  $TARGET/gcc46-all-gcc (step 48), $TARGET/gcc46-libgcc
##          (step 49), $TARGET/tcc-darwin-cc-root (step 44),
##          sources/gcc46-scripts/phase36-bootstrap-as.c,
##          $TARGET/bin/elf64-to-m1 (step 30).
## Outputs: $TARGET/gcc46-bootstrap: bin/gcc wrapper,
##          libexec/gcc/x86_64-apple-darwin/4.6.4/{xgcc,cc1,cpp},
##          lib/gcc/.../4.6.4 (headers + libgcc objects),
##          include/gcc46-bootstrap merged headers, smoke artifacts
##          under share/darwin-bootstrap/.
## Verifies (inside phase37-driver.sh): -S output contains _main; .o
##          output carries the ELF magic; three compile+link+run smoke
##          tests each exit 42 (plain C, __int128 multiply, and a
##          two-file separate-compilation program).
## Trust:   all translation by chain-built tools; Apple sh utilities
##          orchestrate.
set -eu

out="$TARGET/gcc46-bootstrap"
rm -rf "$out"
mkdir -p "$out"

/bin/bash "$SOURCES/gcc46-scripts/phase37-driver.sh" \
    "$TARGET/gcc46-all-gcc" \
    "$TARGET/gcc46-libgcc" \
    "$TARGET/tcc-darwin-cc-root" \
    "$SOURCES/gcc46-scripts/phase36-bootstrap-as.c" \
    "" \
    "$TARGET/bin/elf64-to-m1" \
    "$out" \
    4.6.4
