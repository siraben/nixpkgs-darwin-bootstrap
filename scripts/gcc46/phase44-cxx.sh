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
if grep -q '^#if (GCC_VERSION >= 4005).*defined(__x86_64__)' src/libcpp/lex.c; then
  sed 's/^#if (GCC_VERSION >= 4005)/#if 0 \&\& (GCC_VERSION >= 4005)/' \
    src/libcpp/lex.c > src/libcpp/lex.c.bootstrap
  mv src/libcpp/lex.c.bootstrap src/libcpp/lex.c
fi
if ! grep -q DARWIN_BOOTSTRAP_NULL src/gmp/gmp-impl.h; then
  cat >> src/gmp/gmp-impl.h <<'GMP_NULL'

#ifndef DARWIN_BOOTSTRAP_NULL
#define DARWIN_BOOTSTRAP_NULL 1
#ifndef NULL
#define NULL ((void *)0)
#endif
#endif
GMP_NULL
fi

export CC="$phase37/bin/gcc"
export CPP="$CC -E"
export CC_FOR_BUILD="$CC"
export AR="$cctools/bin/ar"
export NM="$cctools/bin/nm"
export RANLIB="$cctools/bin/ranlib"
export STRIP="$cctools/bin/strip"
export LIPO="$cctools/bin/lipo"
export OTOOL="$cctools/bin/otool"
export PATH="$cctools/bin:$PATH"
export MACOSX_DEPLOYMENT_TARGET=10.6
export CFLAGS="-g"
export CFLAGS_FOR_BUILD="-g"
export TCC_DARWIN_CACHE_DIR="$PWD/.tcc-darwin-cache"
mkdir -p "$TCC_DARWIN_CACHE_DIR"
unset CXX CXXCPP CXX_FOR_BUILD
no_host_cxx="$PWD/.no-host-cxx"
mkdir -p "$no_host_cxx"
for cxx_name in c++ g++ clang++ "$target-c++" "$target-g++"; do
  cat > "$no_host_cxx/$cxx_name" <<'NO_CXX'
#!/usr/bin/env sh
exit 1
NO_CXX
  chmod +x "$no_host_cxx/$cxx_name"
done
cat > "$no_host_cxx/cxx-cpp" <<NO_CXXCPP
#!$(command -v bash)
set -euo pipefail
tmpdir=\$(mktemp -d "\${TMPDIR:-/tmp}/gcc46-cxx-cpp.XXXXXX")
trap 'rm -rf "\$tmpdir"' EXIT HUP INT TERM
args=()
for arg in "\$@"; do
  case "\$arg" in
    *.cc|*.cpp|*.cxx|*.C)
      cp "\$arg" "\$tmpdir/input.c"
      args+=("\$tmpdir/input.c")
      ;;
    *)
      args+=("\$arg")
      ;;
  esac
done
exec "$CC" -E "\${args[@]}"
NO_CXXCPP
chmod +x "$no_host_cxx/cxx-cpp"
export CXXCPP="$no_host_cxx/cxx-cpp"
export PATH="$no_host_cxx:$PATH"

cd build
for cache_dir in \
  gcc \
  libiberty \
  build-x86_64-apple-darwin \
  build-x86_64-apple-darwin/libiberty \
  fixincludes \
  gmp \
  mpfr \
  mpc \
  libcpp \
  libdecnumber \
  zlib \
  intl; do
  if [ -f "$phase35/share/darwin-bootstrap/work/build/$cache_dir/config.cache" ]; then
    mkdir -p "$cache_dir"
    grep -v '^ac_cv_env_' \
      "$phase35/share/darwin-bootstrap/work/build/$cache_dir/config.cache" \
      | grep -v -E '^(ac_cv_prog_(CC|CPP|CXX|CXXCPP|cc_|cxx_)|ac_cv_sys_largefile_CC)=' \
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

make_tool=${BOOTSTRAP_MAKE:-"$phase39/bin/make"}
# The phase39 GNU Make is intentionally minimal and does not yet have a
# bootstrap-proven jobserver/pipe path.  Keep Nix builds serial by default, but
# allow impure debug runs to override both the make executable and job count.
build_cores=${BOOTSTRAP_JOBS:-1}

MAKEFLAGS= "$make_tool" -j"$build_cores" \
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

MAKEFLAGS= "$make_tool" -j"$build_cores" \
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
