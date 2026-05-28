#!/bin/sh
## 46-gcc46-source — extract gcc-4.6.4 + in-tree gmp/mpfr/mpc.
set -eu

out="$TARGET/gcc46-source"
rm -rf "$out"
mkdir -p "$out"

work="$TARGET/work/gcc46-source"
rm -rf "$work"
mkdir -p "$work"
cd "$work"

tar -xf "$ROOT/tarballs/gcc-4.6.4.tar.bz2"
tar -xf "$ROOT/tarballs/gmp-4.3.2.tar.bz2"
tar -xf "$ROOT/tarballs/mpfr-2.4.2.tar.bz2"
tar -xf "$ROOT/tarballs/mpc-0.8.1.tar.gz"

## Move gcc-4.6.4 contents to $out (top-level)
mv gcc-4.6.4/* "$out/"
mv gcc-4.6.4/.[a-z]* "$out/" 2>/dev/null || true

## Drop gmp/mpfr/mpc into their respective in-tree paths
cp -R gmp-4.3.2 "$out/gmp"
cp -R mpfr-2.4.2 "$out/mpfr"
cp -R mpc-0.8.1 "$out/mpc"

test -x "$out/configure"
test -f "$out/gcc/gcc.c"
test -f "$out/gmp/configure"
test -f "$out/mpfr/configure"
test -f "$out/mpc/configure"
echo "gcc46-source extracted to $out"
