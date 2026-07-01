#!/bin/sh
## 47-gcc46-darwin-src — apply Darwin-bootstrap patches to gcc-4.6 source.
##
## Mirrors nix/gcc-4.6/darwin-bootstrap-src.nix: copy gcc46-source and
## apply 3 committed patches from sources/gcc46-patches:
##   - gcc46-genconditions-tcc-safe.patch: genconditions.c drops the
##     __builtin_constant_p probe in its generated table (tcc-compiled
##     genconditions handles the plain constant form);
##   - gcc46-darwin-bootstrap-host.patch: host-darwin.c shrinks the 1 GiB
##     PCH BSS reservation (the M1/hex2 link path materializes BSS and
##     tcc does not preserve large alignment attributes);
##   - gcc46-darwin-macho-driver.patch: darwin-driver.c accepts only
##     "10.x" MACOSX_DEPLOYMENT_TARGET values, plus Mach-O driver fixes.
##
## Runs:    host /usr/bin/patch — trust boundary (text edits from
##          committed, auditable patch files); Apple cp/chmod.
## Inputs:  $TARGET/gcc46-source (step 46); sources/gcc46-patches/*.
## Outputs: $TARGET/gcc46-darwin-bootstrap-src (patched full gcc tree).
## Verifies: /usr/bin/patch exits nonzero on any hunk failure and set -e
##          aborts the step, so all hunks applied cleanly.
set -eu

src_in="$TARGET/gcc46-source"
out="$TARGET/gcc46-darwin-bootstrap-src"
test -d "$src_in" || { echo "missing $src_in" >&2; exit 1; }

rm -rf "$out"
mkdir -p "$out"
cp -R "$src_in/." "$out/"
chmod -R u+w "$out"

cd "$out"
/usr/bin/patch -p1 < "$SOURCES/gcc46-patches/gcc46-genconditions-tcc-safe.patch"
/usr/bin/patch -p1 < "$SOURCES/gcc46-patches/gcc46-darwin-bootstrap-host.patch"
/usr/bin/patch -p1 < "$SOURCES/gcc46-patches/gcc46-darwin-macho-driver.patch"

echo "gcc46-darwin-bootstrap-src ready at $out"
