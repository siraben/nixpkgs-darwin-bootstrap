#!/bin/sh
## 47-gcc46-darwin-src — apply Darwin-bootstrap patches to gcc-4.6 source.
##
## Mirrors gcc-4.6/darwin-bootstrap-src.nix: copy gcc46-source and
## apply 3 patches for tcc compatibility and Darwin Mach-O driver.
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
