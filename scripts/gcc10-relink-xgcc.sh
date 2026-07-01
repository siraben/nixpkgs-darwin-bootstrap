#!/bin/sh
# (Re)build gcc-10's `xgcc` driver in the all-gcc build dir.
#
# xgcc has no C++ static constructors, so unlike cc1 it does not exercise the
# crt1 init-array path; a plain `make xgcc` with the chain env suffices.  Kept
# as a script so the exact env is reproducible and not re-derived by hand.  Run
# after make all-gcc has produced the gcc objects, or after any elf64-to-m1
# change (clear the resolve caches first — see gcc10-link-cc1.sh).
#
# Invoked by step 55 after gcc10-link-cc1.sh; also runnable standalone by
# a maintainer.  Env contract: ROOT optional (self-locates); toolchain and
# paths come from gcc10-env.sh.  Trust: chain make + chain g++ wrapper do
# the link; host find/xargs/touch only adjust mtimes.
set -u

ROOT="${ROOT:-$(cd -- "$(dirname -- "$0")/.." && pwd)}"
. "$ROOT/scripts/gcc10-env.sh"

# Equalize mtimes so make doesn't try to re-run automake / re-resolve unchanged
# objects (see gcc10-resume-make.sh for the rationale).
find "$GCC10_SRC"   -print0 | xargs -0 touch -t 202601010000 2>/dev/null || true
find "$GCC10_BUILD" -print0 | xargs -0 touch -t 202701010000 2>/dev/null || true

cd "$GCC10_BUILD/gcc"; rm -f xgcc
"$MAKE" xgcc -j1 MAKEINFO=true NATIVE_SYSTEM_HEADER_DIR="$GCC10_SYS" \
  CPP="$CPP" CXXCPP="$CXXCPP" AR="$AR" RANLIB="$RANLIB" NM="$NM" \
  AR_FOR_BUILD="$AR_FOR_BUILD" RANLIB_FOR_BUILD="$RANLIB_FOR_BUILD" \
  CFLAGS="$CFLAGS" CXXFLAGS="$CXXFLAGS"
echo "XGCC_RELINK_EXIT=$?"
