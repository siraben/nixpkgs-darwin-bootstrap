#!/bin/sh
## 54-gcc10-configure — configure gcc-10 for an `all-gcc` (C front-end) build
## using ONLY the bake chain toolchain (tcc-darwin-cc + gcc-4.6 g++).
##
## Codifies what was previously a hand-run configure (recovered from the build
## dir's config.log).  --enable-languages=c builds cc1 + xgcc; the C++ front-end
## and target libgcc are out of scope for the from-seed milestone.  The math
## libs (gmp/mpfr/mpc) are built in-tree from the sources staged by step 53;
## --without-isl skips Graphite.
set -eu

. "$ROOT/scripts/gcc10-env.sh"

test -x "$GCC10_SRC/configure" || { echo "54: missing $GCC10_SRC/configure (run step 53)" >&2; exit 1; }

rm -rf "$GCC10_BUILD"
mkdir -p "$GCC10_BUILD"
cd "$GCC10_BUILD"

"$GCC10_SRC/configure" \
  --prefix="$GCC10_INSTALL" \
  --build=x86_64-apple-darwin --host=x86_64-apple-darwin --target=x86_64-apple-darwin \
  --with-native-system-header-dir="$GCC10_SYS" \
  --with-build-sysroot="$GCC10_SYS" \
  --disable-bootstrap --disable-shared --disable-multilib --disable-nls \
  --disable-libsanitizer --disable-libssp --disable-libquadmath --disable-libgomp \
  --disable-dependency-tracking --without-isl \
  --enable-languages=c \
  MAKEINFO=true

test -f "$GCC10_BUILD/Makefile" || { echo "54: configure produced no top Makefile" >&2; exit 1; }
echo "gcc10 configured at $GCC10_BUILD (all-gcc, languages=c)"
