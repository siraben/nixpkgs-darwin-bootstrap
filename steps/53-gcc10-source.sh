#!/bin/sh
## 53-gcc10-source — stage gcc-10.4.0 with gmp/mpfr/mpc/isl placed in-tree
## (mirrors nix/gcc-10/source.nix).  Built later by our gcc-4.6 g++.
##
## gcc-10 is the chain's modern-compiler target: its sources are C++, so
## it needs the from-seed gcc-4.6 cc1plus/g++ (steps 51/52/52b), the
## payoff of building 4.6 first.  The math libraries go in-tree so gcc's
## top-level configure builds them with the chain toolchain (isl is
## staged for completeness; step 54 configures --without-isl).
##
## Runs:    Apple tar/cp/chmod — unpack and file placement only.
## Inputs:  tarballs/gcc-10.4.0.tar.xz, gmp-6.2.1.tar.xz,
##          mpfr-4.2.2.tar.xz, mpc-1.3.1.tar.gz, isl-0.24.tar.bz2
##          (pinned SHA-256, fetched by scripts/fetch-sources.sh).
## Outputs: $TARGET/gcc10-source (gcc tree with gmp/, mpfr/, mpc/, isl/
##          subdirs); scratch tree $TARGET/work/gcc10-source.
## Verifies: presence of configure, gcc/gcc.c, and each in-tree
##          library's configure.
set -eu
. "$ROOT/scripts/tarball-sha256s.sh"

out="$TARGET/gcc10-source"
rm -rf "$out"
mkdir -p "$out"

work="$TARGET/work/gcc10-source"
rm -rf "$work"; mkdir -p "$work"; cd "$work"

for t in gcc-10.4.0.tar.xz gmp-6.2.1.tar.xz mpfr-4.2.2.tar.xz \
         mpc-1.3.1.tar.gz isl-0.24.tar.bz2; do
    boot_verify_tarball "$ROOT/tarballs/$t" || exit 1
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
