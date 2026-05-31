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
# Build-side subdirs (build-x86_64-apple-darwin/libcpp, libiberty) archive
# their .o with AR_FOR_BUILD/RANLIB_FOR_BUILD, NOT AR/RANLIB. Their Makefiles
# default these to plain `ar`, which silently makes an empty archive from our
# ELF members (only __.SYMDEF, zero members) -> "Target label _ZNK... not valid"
# when genmatch links libcpp.a. Force the bake shims here too.
export AR_FOR_BUILD=$ROOT/scripts/bake-ar
export RANLIB_FOR_BUILD=$ROOT/scripts/bake-ranlib
export NM=/usr/bin/nm
export STRIP=/usr/bin/strip
export LIPO=/usr/bin/lipo
export OTOOL=/usr/bin/otool

# NB: we deliberately do NOT delete any sub-configure config.cache/config.status
# here. The depmode probe is handled for good (config.site pins the host subdirs;
# the g++ wrapper's -MF support makes the build-* probe pass). Deleting
# gcc/config.status while gcc/Makefile persists makes the gcc subdir's
# "config.status:" rule abort with "You must configure gcc" once the build
# advances into gcc proper. Leave the configured state intact and just resume.

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
  CPP="$CPP" CXXCPP="$CXXCPP" AR="$AR" RANLIB="$RANLIB" NM="$NM" \
  AR_FOR_BUILD="$AR_FOR_BUILD" RANLIB_FOR_BUILD="$RANLIB_FOR_BUILD"
