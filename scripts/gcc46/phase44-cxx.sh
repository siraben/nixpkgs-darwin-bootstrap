#!/usr/bin/env bash
set -euo pipefail

phase35=$1
phase37=$2
phase39=$3
phase34=$4
cctools=$5
out=$6
gcc_version=$7

target=x86_64-apple-darwin
bootstrap_share="$out/share/darwin-bootstrap"

mkdir -p src build "$out/bin" "$bootstrap_share"
cp -R "$phase35/share/darwin-bootstrap/work/src/." src/
chmod -R u+w src

export CC="$phase37/bin/gcc"
export CPP="$CC -E"
export CC_FOR_BUILD="$CC"
export AR="$cctools/bin/ar"
export NM="$cctools/bin/nm"
export RANLIB="$cctools/bin/ranlib"
export STRIP="$cctools/bin/strip"
export LIPO="$cctools/bin/lipo"
export OTOOL="$cctools/bin/otool"
export MACOSX_DEPLOYMENT_TARGET=10.6
export CFLAGS="-g"
export CFLAGS_FOR_BUILD="-g"
export TCC_DARWIN_CACHE_DIR="$PWD/.tcc-darwin-cache"
mkdir -p "$TCC_DARWIN_CACHE_DIR"

cd build
for cache_dir in gcc libiberty build-x86_64-apple-darwin/libiberty mpfr mpc; do
  if [ -f "$phase35/share/darwin-bootstrap/work/build/$cache_dir/config.cache" ]; then
    mkdir -p "$cache_dir"
    grep -v '^ac_cv_env_' \
      "$phase35/share/darwin-bootstrap/work/build/$cache_dir/config.cache" \
      > "$cache_dir/config.cache"
    chmod u+w "$cache_dir/config.cache"
  fi
done

../src/configure \
  --prefix="$out" \
  --build="$target" \
  --host="$target" \
  --target="$target" \
  --with-native-system-header-dir="$phase34/include/tcc-darwin-bootstrap" \
  --with-build-sysroot="$phase34/include/tcc-darwin-bootstrap" \
  --disable-bootstrap \
  --disable-shared \
  --disable-multilib \
  --disable-nls \
  --disable-libmudflap \
  --disable-libstdcxx-pch \
  --disable-lto \
  --enable-languages=c,c++ \
  MAKEINFO=true \
  > "$bootstrap_share/configure.stdout" \
  2> "$bootstrap_share/configure.stderr"

mkdir -p intl
cat > intl/Makefile <<'MAKE'
all:
install:
install-strip:
clean:
MAKE

# The phase39 GNU Make is intentionally minimal and does not yet have a
# bootstrap-proven jobserver/pipe path.  Keep this phase serial until that is
# fixed instead of paying for another long GCC replay just to fail in make -j.
build_cores=1

MAKEFLAGS= "$phase39/bin/make" -j"$build_cores" \
  MAKEINFO=true \
  CC="$CC" \
  CPP="$CPP" \
  AR="$AR" \
  NM="$NM" \
  RANLIB="$RANLIB" \
  STRIP="$STRIP" \
  LIPO="$LIPO" \
  OTOOL="$OTOOL" \
  all-gcc all-target-libstdc++-v3 \
  > "$bootstrap_share/make.stdout" \
  2> "$bootstrap_share/make.stderr"

MAKEFLAGS= "$phase39/bin/make" -j"$build_cores" \
  MAKEINFO=true \
  install-gcc install-target-libstdc++-v3 \
  > "$bootstrap_share/install.stdout" \
  2> "$bootstrap_share/install.stderr"

test -x "$out/bin/gcc"
test -x "$out/bin/g++"
"$out/bin/g++" --version > "$bootstrap_share/g++-version.stdout"

cat > cxx-smoke.cc <<'CC'
int helper(int x) { return x + 40; }
int main() { return helper(2); }
CC
"$out/bin/g++" -S cxx-smoke.cc -o "$bootstrap_share/cxx-smoke.s" \
  > "$bootstrap_share/cxx-smoke.stdout" \
  2> "$bootstrap_share/cxx-smoke.stderr"
test -s "$bootstrap_share/cxx-smoke.s"
