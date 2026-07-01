#!/bin/sh
## 46-gcc46-source — extract gcc-4.6.4 + in-tree gmp/mpfr/mpc.
##
## gcc-4.6 is the bridge target for the chain tcc: it is written in C
## (GCC's own sources require a C++ compiler from 4.8 on), so
## tcc-darwin-cc can compile it, and once built it provides the C++
## front-end (cc1plus, steps 51-52b) that gcc-10 requires.  gmp/mpfr/mpc
## are placed in-tree so gcc's top-level configure builds them itself
## with the chain toolchain; nothing is taken from the host.
##
## Runs:    Apple tar/mv/cp — unpack and file placement only, no
##          translation of any kind.
## Inputs:  tarballs/gcc-4.6.4.tar.bz2, gmp-4.3.2.tar.bz2,
##          mpfr-2.4.2.tar.bz2, mpc-0.8.1.tar.gz (pinned SHA-256,
##          fetched by scripts/fetch-sources.sh).
## Outputs: $TARGET/gcc46-source (gcc tree with gmp/, mpfr/, mpc/
##          subdirs); scratch tree $TARGET/work/gcc46-source.
## Verifies: presence of configure, gcc/gcc.c, and each in-tree math
##          library's configure — the trees landed where gcc's build
##          expects them.
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
