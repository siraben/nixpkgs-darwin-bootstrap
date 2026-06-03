#!/bin/sh
## 52b-gcc46-libstdcxx — configure + build gcc-4.6's libstdc++-v3 into
## work/libstdcxx46.
##
## The g++ wrapper installed by step 52 points its C++ include/link path at
## $TARGET/work/libstdcxx46 (headers incl. the GENERATED bits/c++config.h, plus
## libstdc++.a).  gcc-10 is C++ and its very first build artifact (build-side
## libcpp) #include <new>, which pulls in bits/c++config.h — so without this
## library gcc-10's step 55 fails at all-build-libcpp.  This step was done by
## hand originally (STATUS.md); the recipe here is recovered verbatim from the
## manual build's work/libstdcxx46/config.log.
##
## Historically the libstdc++ configure was impractical (every C++ conftest
## links a ~51 MB Mach-O); the dynamic per-link Mach-O layout (in tcc-darwin-cc
## + m1-to-hex2) and running with stdin </dev/null (build.sh) make it tractable.
set -eu

src="$TARGET/gcc46-darwin-bootstrap-src/libstdc++-v3"
test -x "$src/configure"                || { echo "52b: missing $src/configure" >&2; exit 1; }
test -x "$TARGET/gcc46-cxx/bin/g++"      || { echo "52b: missing g++ wrapper (run step 52)" >&2; exit 1; }
test -x "$TARGET/bin/tcc-darwin-cc"      || { echo "52b: missing tcc-darwin-cc" >&2; exit 1; }

work="$TARGET/work/libstdcxx46"
rm -rf "$work"
mkdir -p "$work"
cd "$work"

export PATH="$TARGET/bin:/usr/bin:/bin"
export MACOSX_DEPLOYMENT_TARGET=10.6
export CC="$TARGET/bin/tcc-darwin-cc"
export CXX="$TARGET/gcc46-cxx/bin/g++"
export CPPFLAGS="-isystem $TARGET/tcc-darwin-cc-root/include/tcc-darwin-bootstrap"
export CXXFLAGS="-g"
export AR="$ROOT/scripts/bake-ar"
export RANLIB="$ROOT/scripts/bake-ranlib"
export NM=/usr/bin/nm

echo "== configuring gcc-4.6 libstdc++-v3 (slow: C++ conftests) =="
"$src/configure" \
  --host=x86_64-apple-darwin --build=x86_64-apple-darwin \
  --disable-shared --disable-libstdcxx-pch --disable-multilib \
  --enable-threads=single --enable-cstdio=stdio \
  MAKEINFO=true

# Our gcc-4.6 reports no thread model, so libstdc++'s configure leaves the
# gthread header name empty (glibcxx_thread_h="gthr-.h"), and `make` then fails
# looking for gcc/gthr-.h.  Provide it as the single-threaded variant (matches
# --enable-threads=single); the manual build had the same workaround.
cp "$TARGET/gcc46-darwin-bootstrap-src/gcc/gthr-single.h" \
   "$TARGET/gcc46-darwin-bootstrap-src/gcc/gthr-.h"

echo "== building libstdc++ (make all) =="
"$TARGET/bin/make" all -j1 MAKEINFO=true AR="$AR" RANLIB="$RANLIB" NM="$NM"

test -f "$work/include/x86_64-apple-darwin/bits/c++config.h" \
  || { echo "52b: c++config.h not generated" >&2; exit 1; }
echo "gcc-4.6 libstdc++ built at $work (bits/c++config.h generated)"
