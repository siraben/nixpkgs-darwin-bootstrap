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
##           host /usr/bin/patch — trust boundary (the chain has no
##           patch tool built at this point).
## Inputs:   sources/tinycc/tinycc-bootstrappable/ (committed tree),
##           sources/tinycc/tinycc-mes-bootstrap.patch.
## Outputs:  target/tinycc-mes-src/ (patched tree + empty config.h).
## Verifies: patch's own exit status only.
## Trust:    host /usr/bin/patch rewrites compiler source text; the
##           patch file itself is committed and auditable.
set -eu

out="$TARGET/tinycc-mes-src"
rm -rf "$out"
mkdir -p "$out"
cp -R "$SOURCES/tinycc/tinycc-bootstrappable/." "$out/"
chmod -R u+w "$out"
cd "$out"
## Trust boundary: host patch applies the committed mes-bootstrap diff.
/usr/bin/patch -p1 < "$SOURCES/tinycc/tinycc-mes-bootstrap.patch"
## tcc.h includes config.h; all configuration comes from -D flags, so
## an empty file suffices.
: > config.h
