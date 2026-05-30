#!/bin/sh
# Resume gcc-10 `make all-gcc` in the existing build dir with the full
# chain toolchain env. Codifies the env that has otherwise been ad-hoc.
set -eu

ROOT=${ROOT:-/Users/siraben/Git/nixpkgs-darwin-bootstrap/bake}
TARGET=$ROOT/target
B=$TARGET/work/gcc10-all-gcc/build
SYS=$TARGET/tcc-darwin-cc-root/include/tcc-darwin-bootstrap

export LC_ALL=C
export MACOSX_DEPLOYMENT_TARGET=10.6
export CONFIG_SITE=$ROOT/sources/gcc10-darwin/config.site
export TCC_DARWIN_CACHE_DIR=${TCC_DARWIN_CACHE_DIR:-$ROOT/.tcc-darwin-archive-cache}

export CC=$TARGET/bin/tcc-darwin-cc
export CXX=$TARGET/gcc46-cxx/bin/g++
export CPP=$ROOT/scripts/tcc-cpp
export CXXCPP=$ROOT/scripts/gxx-cpp
export CC_FOR_BUILD=$CC
export CXX_FOR_BUILD=$CXX
export CXXFLAGS="-g -std=gnu++0x -mno-sse3"
export CFLAGS="-g"
export AR=$ROOT/scripts/bake-ar
export RANLIB=$ROOT/scripts/bake-ranlib
export NM=/usr/bin/nm
export STRIP=/usr/bin/strip
export LIPO=/usr/bin/lipo
export OTOOL=/usr/bin/otool

# Drop stale sub-configures so the depmode probe re-runs cleanly on retry.
# Host subdirs read config.site (am_cv_*_dependencies_compiler_type=gcc3); the
# build-* subdirs are forced CONFIG_SITE=no-such-file by the top Makefile, so
# they rely on the g++ wrapper now emitting a -MF depfile (probe passes
# naturally). Any cache holding a stale "=none" would re-trigger the fatal
# "no usable dependency style found", so clear them all.
for d in gcc libgcc libatomic; do
  rm -f "$B/$d/config.cache" "$B/$d/config.status" 2>/dev/null || true
done
find "$B" -path '*build-*/config.cache' -delete 2>/dev/null || true
find "$B" -path '*build-*' -name config.cache -delete 2>/dev/null || true

# Normalize source-tree mtimes to one fixed past timestamp. The host clock has
# drifted behind the checked-out file mtimes ("modification time in the future"),
# so make sees Makefile.am newer than Makefile.in and tries to re-run automake
# (which is not installed) -> "automake-1.17: command not found". Equal mtimes
# across the tree disable the entire maintainer-mode regen chain (configure:
# configure.ac, Makefile.in: Makefile.am, aclocal.m4: *.m4 all become "not newer").
SRC=$TARGET/gcc10-source
if [ -d "$SRC" ]; then
  find "$SRC" -print0 | xargs -0 touch -t 202601010000 2>/dev/null || true
fi

cd "$B"
exec make all-gcc -j1 MAKEINFO=true \
  NATIVE_SYSTEM_HEADER_DIR="$SYS" \
  CPP="$CPP" CXXCPP="$CXXCPP" AR="$AR" RANLIB="$RANLIB" NM="$NM"
