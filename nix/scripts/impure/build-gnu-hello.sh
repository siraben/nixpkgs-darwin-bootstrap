#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/../.." && pwd)
gcc_prefix=${GCC_PREFIX:-"$repo_root/work/impure/phase47-gcc16-strict/out"}
hello_src=${HELLO_SRC:-"$repo_root/work/gnu/hello-2.12.2"}
build_dir=${HELLO_BUILD_DIR:-"$repo_root/work/validation/hello-strict-o2"}

if [ ! -x "$gcc_prefix/bin/gcc" ]; then
  echo "missing GCC wrapper: $gcc_prefix/bin/gcc" >&2
  exit 1
fi
if [ ! -x "$hello_src/configure" ]; then
  echo "missing GNU Hello source configure script: $hello_src/configure" >&2
  exit 1
fi

rm -rf "$build_dir"
mkdir -p "$build_dir"
cd "$build_dir"

export PATH="$gcc_prefix/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export CC="$gcc_prefix/bin/gcc"
export CXX="$gcc_prefix/bin/g++"
export GCC_MODERN_WRAPPER_HOST_SHORTCUTS="${GCC_MODERN_WRAPPER_HOST_SHORTCUTS:-0}"
export GCC_MODERN_CONFTEST_TIMEOUT="${GCC_MODERN_CONFTEST_TIMEOUT:-120}"
export CFLAGS="${CFLAGS:--O2 -g0}"
export CXXFLAGS="${CXXFLAGS:--O2 -g0}"

"$hello_src/configure" --disable-nls --prefix="$build_dir/install" \
  > configure.stdout \
  2> configure.stderr

/usr/bin/make -j"${BOOTSTRAP_JOBS:-4}" ARFLAGS="${ARFLAGS:-rc}" \
  > make.stdout \
  2> make.stderr

./hello > hello.stdout
./hello --version > version.stdout
./hello --help > help.stdout

grep -qx 'Hello, world!' hello.stdout
grep -q 'GNU Hello' version.stdout
grep -q 'Usage:' help.stdout

file ./hello
shasum -a 256 ./hello
