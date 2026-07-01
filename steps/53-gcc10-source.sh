#!/bin/sh
## 53-gcc10-source — stage gcc-10.4.0 with gmp/mpfr/mpc/isl placed in-tree
## (mirrors gcc-10/source.nix).  Built later by our gcc-4.6 g++.
set -eu

out="$TARGET/gcc10-source"
rm -rf "$out"
mkdir -p "$out"

work="$TARGET/work/gcc10-source"
rm -rf "$work"; mkdir -p "$work"; cd "$work"

for t in gcc-10.4.0.tar.xz gmp-6.2.1.tar.xz mpfr-4.2.2.tar.xz \
         mpc-1.3.1.tar.gz isl-0.24.tar.bz2; do
    test -f "$ROOT/tarballs/$t" || { echo "missing $ROOT/tarballs/$t (run fetch-sources.sh)" >&2; exit 1; }
    tar -xf "$ROOT/tarballs/$t"
done

cp -R gcc-10.4.0/. "$out/"
chmod -R u+w "$out"
cp -R gmp-6.2.1   "$out/gmp"
cp -R mpfr-4.2.2  "$out/mpfr"
cp -R mpc-1.3.1   "$out/mpc"
cp -R isl-0.24    "$out/isl"

test -x "$out/configure"
test -f "$out/gcc/gcc.c"
test -f "$out/gmp/configure"
test -f "$out/mpfr/configure"
test -f "$out/mpc/configure"
test -f "$out/isl/configure"
echo "gcc10-source staged at $out (gcc-10.4.0 + in-tree gmp/mpfr/mpc/isl)"
