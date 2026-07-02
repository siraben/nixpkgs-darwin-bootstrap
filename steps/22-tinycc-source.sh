#!/bin/sh
## 22-tinycc-source — stage the tinycc source tree for the boot cycle.
## Equivalent of `tinyccMesSrc` in packages.nix.
##
## Copies the committed tinycc-bootstrappable tree into target/ and
## applies the mes-bootstrap patch, producing the single source tree
## that every tinycc compile in steps 23–41 reads (the mescc pass and
## all self-compile generations read the same bytes, so the boot cycle
## varies only the compiler binary).  An empty config.h is created
## because tcc.h does `#include "config.h"` and no configure runs.
##
## Runs:     Apple /usr/bin cp/chmod/mkdir for orchestration;
##           chain boot-patch from step 14b applies the committed
##           source diff.
## Inputs:   sources/tinycc/tinycc-bootstrappable/ (committed tree),
##           sources/tinycc/tinycc-mes-bootstrap.patch.
## Outputs:  target/tinycc-mes-src/ (patched tree + empty config.h).
## Verifies: boot-patch exits nonzero on any hunk failure and set -e
##           aborts the step.
## Trust:    source edit is performed by chain-built boot-patch; the
##           patch file itself is committed and auditable.
set -eu

out="$TARGET/tinycc-mes-src"
rm -rf "$out"
mkdir -p "$out"
cp -R "$SOURCES/tinycc/tinycc-bootstrappable/." "$out/"
chmod -R u+w "$out"
cd "$out"
boot-patch -p1 < "$SOURCES/tinycc/tinycc-mes-bootstrap.patch"
## tcc.h includes config.h; all configuration comes from -D flags, so
## an empty file suffices.
: > config.h
