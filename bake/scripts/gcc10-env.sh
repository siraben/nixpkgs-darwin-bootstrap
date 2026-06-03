# Shared environment for the gcc-10 from-seed build (configure / make / link).
# SOURCE this (do not execute); it expects ROOT and TARGET in the environment
# (set by build.sh) and defines the toolchain env + standard path variables.
#
# Everything here is from the bake chain — nothing from the host toolchain:
#   CC   = tcc-darwin-cc            (our tinycc-derived C compiler driver)
#   CXX  = gcc46-cxx/bin/g++        (our from-seed gcc-4.6 g++)
#   CPP/CXXCPP = chain preprocessors
#   AR/RANLIB  = bake-ar/bake-ranlib (deterministic, produce ELF .a the chain reads)
#   NM/STRIP/LIPO/OTOOL = Apple system binutils (inspection only, no codegen)

ROOT="${ROOT:?gcc10-env.sh: ROOT must be set}"
TARGET="${TARGET:-$ROOT/target}"

# Standard locations for the gcc-10 build.
GCC10_SRC="$TARGET/gcc10-source"
GCC10_BUILD="$TARGET/work/gcc10-all-gcc/build"
GCC10_INSTALL="$TARGET/work/gcc10-all-gcc/install"
GCC10_SYS="$TARGET/tcc-darwin-cc-root/include/tcc-darwin-bootstrap"
export GCC10_SRC GCC10_BUILD GCC10_INSTALL GCC10_SYS

export LC_ALL=C
export MACOSX_DEPLOYMENT_TARGET=10.6
export CONFIG_SITE="$ROOT/sources/gcc10-darwin/config.site"
export TCC_DARWIN_CACHE_DIR="${TCC_DARWIN_CACHE_DIR:-$ROOT/.tcc-darwin-archive-cache}"

export CC="$TARGET/bin/tcc-darwin-cc"
export CXX="$TARGET/gcc46-cxx/bin/g++"
export CPP="$ROOT/scripts/tcc-cpp"
export CXXCPP="$ROOT/scripts/gxx-cpp"
export CC_FOR_BUILD="$CC"
export CXX_FOR_BUILD="$CXX"

# GC tuning + flag rationale: see bake/scripts/gcc10-resume-make.sh and STATUS.md.
# -O0 keeps cc1plus (running under Rosetta 2) tractable; -fpermissive downgrades
# gcc-10's C++11 narrowing errors that gcc-4.6 cc1plus treats as hard errors.
GCC10_GGC="--param ggc-min-heapsize=1048576 --param ggc-min-expand=400"
export GCC10_GGC
export CXXFLAGS="-O0 -std=gnu++0x -mno-sse3 -fpermissive $GCC10_GGC"
export CFLAGS="-O0 $GCC10_GGC"

# Use the chain's own GNU Make explicitly, not whatever `make` is on PATH, so
# these scripts are faithful even when run standalone (outside build.sh's PATH).
export MAKE="${MAKE:-$TARGET/bin/make}"

export AR="$ROOT/scripts/bake-ar"
export RANLIB="$ROOT/scripts/bake-ranlib"
export AR_FOR_BUILD="$AR"
export RANLIB_FOR_BUILD="$RANLIB"
export NM=/usr/bin/nm
export STRIP=/usr/bin/strip
export LIPO=/usr/bin/lipo
export OTOOL=/usr/bin/otool
