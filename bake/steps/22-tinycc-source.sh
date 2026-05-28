#!/bin/sh
## 22-tinycc-source — copy tinycc-bootstrappable into target/ and
## apply the mes-bootstrap patch.  Equivalent of `tinyccMesSrc` in
## packages.nix.
set -eu

out="$TARGET/tinycc-mes-src"
rm -rf "$out"
mkdir -p "$out"
cp -R "$SOURCES/tinycc/tinycc-bootstrappable/." "$out/"
chmod -R u+w "$out"
cd "$out"
/usr/bin/patch -p1 < "$SOURCES/tinycc/tinycc-mes-bootstrap.patch"
: > config.h
