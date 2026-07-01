#!/bin/sh
# Resume gcc-10 `make all-gcc` in the existing build dir with the full
# chain toolchain env. Codifies the env that has otherwise been ad-hoc.
set -eu

ROOT="${ROOT:-$(cd -- "$(dirname -- "$0")/.." && pwd)}"
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
# Drop -g: our cc1plus runs x86-64 under Rosetta 2 and generating DWARF debug
# info for the huge generated files (insn-emit.c/insn-recog.c have thousands of
# gen_* functions) costs HOURS per file (insn-emit.o was 3h48m+ at -O0 with -g,
# 1.2G RSS).  A working xgcc-10 does not need debug symbols in its own binaries,
# so compile without -g — this cuts per-file time several-fold and makes the
# from-seed build practically completable.  Passed on the make command line
# below so it overrides the configure-baked `CXXFLAGS = -g` in gcc/Makefile;
# already-built (-g) .o are kept (mixed -g/non-g objects link fine).
# GC tuning: the huge generated files (insn-emit.c/insn-recog.c, thousands of
# gen_* functions) build a ~1.2 GB live GGC heap.  gcc-4.6's default
# ggc-min-heapsize is ~4 MB, so cc1plus mark-sweeps that whole heap after nearly
# every function -> O(n^2) GC thrash (insn-emit.c was 4h+ at -O0 with a stable
# 1.2 GB heap stuck in the GGC mark loop; -g made no difference because the heap
# is function trees, not debug info).  Raise the thresholds so GC almost never
# runs during these compiles.  The g++ wrapper forwards unknown tokens to cc1plus
# via its catch-all, so `--param NAME=VAL` reaches cc1plus directly.
GGC="--param ggc-min-heapsize=1048576 --param ggc-min-expand=400"
# -fpermissive: gcc-4.6 cc1plus rejects some C++11 brace-init narrowing in
# gcc-10's source (e.g. opts-common.c:1520, long long -> int) as a hard ERROR;
# downgrade to a warning so the build proceeds.  (-Wno-narrowing would be dropped
# by the g++ wrapper, which strips -W*; -fpermissive forwards via the -f* rule.)
export CXXFLAGS="-O0 -std=gnu++0x -mno-sse3 -fpermissive $GGC"
export CFLAGS="-O0 $GGC"
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

# Force build-side archives to use bake-ar. The build-x86_64-apple-darwin/libcpp
# Makefile hardcodes `AR = ar` (Apple's), which silently produces an empty
# __.SYMDEF-only archive from our ELF objects -> genmatch fails to link
# ("Target label _ZNK13rich_location7get_locEj is not valid"). A command-line
# AR_FOR_BUILD override does NOT reach it: the top Makefile only EXPORTS
# AR=$(AR_FOR_BUILD) into the sub-make environment, and a Makefile `AR =`
# assignment beats an environment variable. So patch the generated Makefile
# directly (idempotent; the regex no-ops once already pointing at bake-ar).
for mk in "$B"/build-*/libcpp/Makefile; do
  [ -f "$mk" ] && sed -i.bak "s|^AR = ar\$|AR = $AR|" "$mk"
done

cd "$B"
exec "${MAKE:-$TARGET/bin/make}" all-gcc -j1 MAKEINFO=true \
  NATIVE_SYSTEM_HEADER_DIR="$SYS" \
  CPP="$CPP" CXXCPP="$CXXCPP" AR="$AR" RANLIB="$RANLIB" NM="$NM" \
  AR_FOR_BUILD="$AR_FOR_BUILD" RANLIB_FOR_BUILD="$RANLIB_FOR_BUILD" \
  CFLAGS="$CFLAGS" CXXFLAGS="$CXXFLAGS"
