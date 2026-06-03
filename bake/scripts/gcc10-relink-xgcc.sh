#!/bin/sh
# (Re)build gcc-10's `xgcc` driver in the all-gcc build dir.
#
# xgcc has no C++ static constructors, so unlike cc1 it does not exercise the
# crt1 init-array path; a plain `make xgcc` with the chain env suffices.  Kept
# as a script so the exact env (GGC tuning, bake-ar, tcc-darwin-cc as CC) is
# reproducible and not re-derived by hand.  Run after gcc10-resume-make.sh has
# produced the gcc objects, or after any elf64-to-m1 change (clear the resolve
# caches first — see gcc10-link-cc1.sh).
set -u

ROOT="${ROOT:-$(cd -- "$(dirname -- "$0")/.." && pwd)}"
TARGET="${TARGET:-$ROOT/target}"
B="${B:-$TARGET/work/gcc10-all-gcc/build}"
SYS="$TARGET/tcc-darwin-cc-root/include/tcc-darwin-bootstrap"
SRC="$TARGET/gcc10-source"

export LC_ALL=C MACOSX_DEPLOYMENT_TARGET=10.6 CONFIG_SITE="$ROOT/sources/gcc10-darwin/config.site"
export TCC_DARWIN_CACHE_DIR="${TCC_DARWIN_CACHE_DIR:-$ROOT/.tcc-darwin-archive-cache}"
export CC="$TARGET/bin/tcc-darwin-cc" CXX="$TARGET/gcc46-cxx/bin/g++"
export CPP="$ROOT/scripts/tcc-cpp" CXXCPP="$ROOT/scripts/gxx-cpp" CC_FOR_BUILD="$CC" CXX_FOR_BUILD="$CXX"
export AR="$ROOT/scripts/bake-ar" RANLIB="$ROOT/scripts/bake-ranlib"
export AR_FOR_BUILD="$AR" RANLIB_FOR_BUILD="$RANLIB"
export NM=/usr/bin/nm
GGC="--param ggc-min-heapsize=1048576 --param ggc-min-expand=400"
export CXXFLAGS="-O0 -std=gnu++0x -mno-sse3 -fpermissive $GGC" CFLAGS="-O0 $GGC"

# Equalize mtimes so make doesn't try to re-run automake / re-resolve unchanged
# objects (see gcc10-resume-make.sh for the rationale).
find "$SRC" -print0 | xargs -0 touch -t 202601010000 2>/dev/null || true
find "$B"   -print0 | xargs -0 touch -t 202701010000 2>/dev/null || true

cd "$B/gcc"; rm -f xgcc
make xgcc -j1 MAKEINFO=true NATIVE_SYSTEM_HEADER_DIR="$SYS" \
  CPP="$CPP" CXXCPP="$CXXCPP" AR="$AR" RANLIB="$RANLIB" NM="$NM" \
  AR_FOR_BUILD="$AR_FOR_BUILD" RANLIB_FOR_BUILD="$RANLIB_FOR_BUILD" \
  CFLAGS="$CFLAGS" CXXFLAGS="$CXXFLAGS"
echo "XGCC_RELINK_EXIT=$?"
