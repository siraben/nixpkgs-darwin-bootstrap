#!/bin/sh
## 49-gcc46-libgcc — build libgcc using xgcc + cc1 from phase 48.
## Mirrors nix/gcc-4.6/libgcc.nix, which calls the same libgcc.sh.
##
## libgcc supplies the runtime support routines gcc-emitted code calls
## implicitly (64/128-bit arithmetic, soft-float TFmode, unwinding);
## the gcc-4.6 driver of step 50 links its objects into every program.
##
## Runs:    phase36-libgcc.sh (symlink to nix/scripts/gcc-4.6/libgcc.sh,
##          bash), driving:
##          - xgcc + cc1 from step 48 (compilation, wrapped by
##            phase36-xgcc-wrapper.sh);
##          - the bootstrap-as filter compiled from phase36-bootstrap-as.c
##            by the chain tcc-darwin-cc (translates gcc's GAS assembly
##            output into the form tcc assembles);
##          - chain tcc-darwin-cc for assembling and linking;
##          - chain boot-ar (via the exported AR shim) for archiving;
##          - host /usr/bin/perl running phase36-libgcc.pl — trust
##            boundary (build-tree text edits only);
##          - Apple /usr/bin binutils (arg 3) for nm/strip/lipo/otool
##            inspection roles.
## Inputs:  $TARGET/gcc46-all-gcc (step 48: xgcc/cc1 + preserved
##          src/build trees); $TARGET/tcc-darwin-cc-root (step 44);
##          sources/gcc46-scripts/phase36-*.
## Outputs: $TARGET/gcc46-libgcc/lib/gcc/x86_64-apple-darwin/4.6.4/
##          {libgcc.a, libgcov.a, libgcc-objects/*.o} plus logs and
##          member lists under share/darwin-bootstrap/.
## Verifies (inside phase36-libgcc.sh): libgcc.a/libgcov.a are non-empty;
##          soft-float and unwind objects carry the ELF magic (chain
##          object format); expected members are present in the archive.
## Trust:   host perl edits build-tree text; all code generation is by
##          the chain-built xgcc/cc1/tcc; Apple binutils inspect only.
set -eu

phase35="$TARGET/gcc46-all-gcc"
test -d "$phase35" || { echo "missing $phase35 (run 48-gcc46-all-gcc first)" >&2; exit 1; }

out="$TARGET/gcc46-libgcc"
rm -rf "$out"
mkdir -p "$out"

## Use the ELF-capable boot-ar / no-op boot-ranlib (Apple's ar drops our
## ELF objects); phase36-libgcc.sh honors a pre-set AR/RANLIB.
export AR="$ROOT/scripts/boot-ar"
export RANLIB="$ROOT/scripts/boot-ranlib"
export LC_ALL=C LANG=C

## Positional args: all-gcc tree, tcc root, Apple binutils dir, perl,
## perl helper, bootstrap-as source, output dir, gcc version, xgcc
## wrapper template.
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
