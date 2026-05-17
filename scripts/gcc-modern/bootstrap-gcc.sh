#!/usr/bin/env bash
set -euo pipefail

source_dir=$1
compiler=$2
phase39=$3
phase34=$4
cctools=$5
out=$6
version=$7
label=$8

target=x86_64-apple-darwin
bootstrap_share="$out/share/darwin-bootstrap"

mkdir -p src build "$out" "$bootstrap_share"
cp -R "$source_dir/." src/
chmod -R u+w src

if [ ! -x "$compiler/bin/g++" ]; then
  echo "$label requires a bootstrapped C++ compiler at $compiler/bin/g++" >&2
  exit 1
fi

cd build
export CC="$compiler/bin/gcc"
export CXX="$compiler/bin/g++"
export CPP="$CC -E"
export CXXCPP="$CXX -E"
export AR="$cctools/bin/ar"
export AS="$cctools/bin/as"
export LD="$cctools/bin/ld"
export NM="$cctools/bin/nm"
export RANLIB="$cctools/bin/ranlib"
export STRIP="$cctools/bin/strip"
export LIPO="$cctools/bin/lipo"
export OTOOL="$cctools/bin/otool"
export PATH="$cctools/bin:$PATH"
export MACOSX_DEPLOYMENT_TARGET=10.6
export CFLAGS="-g"
export CXXFLAGS="-g"
export CFLAGS_FOR_TARGET="-g"
export CXXFLAGS_FOR_TARGET="-g"

../src/configure \
  --prefix="$out" \
  --build="$target" \
  --host="$target" \
  --target="$target" \
  --with-native-system-header-dir="$phase34/include/tcc-darwin-bootstrap" \
  --with-build-sysroot="$phase34/include/tcc-darwin-bootstrap" \
  --disable-bootstrap \
  --disable-dependency-tracking \
  --disable-libatomic \
  --disable-libgomp \
  --disable-libitm \
  --disable-libquadmath \
  --disable-libsanitizer \
  --disable-libssp \
  --disable-lto \
  --disable-multilib \
  --disable-plugin \
  --disable-vtable-verify \
  --disable-nls \
  --enable-languages=c,c++ \
  MAKEINFO=true \
  > "$bootstrap_share/configure.stdout" \
  2> "$bootstrap_share/configure.stderr"

# The bootstrapped GNU Make available at this point is still serial-only for
# this chain: its parallel jobserver needs pipe coverage that has not been made
# part of the bootstrap ABI yet.
build_cores=1

MAKEFLAGS= "$phase39/bin/make" -j"$build_cores" \
  MAKEINFO=true \
  > "$bootstrap_share/make.stdout" \
  2> "$bootstrap_share/make.stderr"

MAKEFLAGS= "$phase39/bin/make" -j"$build_cores" install \
  MAKEINFO=true \
  > "$bootstrap_share/install.stdout" \
  2> "$bootstrap_share/install.stderr"

test -x "$out/bin/gcc"
test -x "$out/bin/g++"
"$out/bin/gcc" --version > "$bootstrap_share/gcc-version.stdout"
"$out/bin/g++" --version > "$bootstrap_share/g++-version.stdout"

cat > smoke.c <<'C'
int main(void) { return 42; }
C
"$out/bin/gcc" -S smoke.c -o "$bootstrap_share/smoke.s" \
  > "$bootstrap_share/smoke.stdout" \
  2> "$bootstrap_share/smoke.stderr"
test -s "$bootstrap_share/smoke.s"
