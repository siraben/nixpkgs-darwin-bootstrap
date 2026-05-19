#!/usr/bin/env bash
set -euo pipefail

phase35=$1
phase34=$2
cctools=$3
python=$4
helper=$5
awk_filter=$6
out=$7
gcc_version=$8
xgcc_wrapper_template=${9:-}

soft_fp_objects=(
  addtf3 divtf3 eqtf2 getf2 letf2 multf3 negtf2 subtf3 unordtf2
  fixtfsi fixunstfsi floatsitf floatunsitf fixtfdi fixunstfdi floatditf floatunditf
  fixtfti fixunstfti floattitf floatuntitf extendsftf2 extenddftf2 extendxftf2
  trunctfsf2 trunctfdf2 trunctfxf2
)
eh_objects=(unwind-dw2 unwind-dw2-fde-darwin unwind-sjlj unwind-c emutls)

mkdir -p work "$out/lib/gcc/x86_64-apple-darwin/$gcc_version" "$out/share/darwin-bootstrap"
cp -R "$phase35/share/darwin-bootstrap/work/src" work/src
cp -R "$phase35/share/darwin-bootstrap/work/build" work/build
chmod -R u+w work

"$python" "$helper" --root "$PWD" --phase34 "$phase34"

export CC="$phase34/bin/tcc-darwin-cc"
export CPP="$CC -E"
export CC_FOR_BUILD="$CC"
export AR="$cctools/bin/ar"
export NM="$cctools/bin/nm"
export RANLIB="$cctools/bin/ranlib"
export STRIP="$cctools/bin/strip"
export LIPO="$cctools/bin/lipo"
export OTOOL="$cctools/bin/otool"
export CFLAGS="-g"
export CFLAGS_FOR_BUILD="-g"
export CXX="$CC"
export CXXCPP="$CC -E"
export TCC_DARWIN_CACHE_DIR="$PWD/.tcc-darwin-cache"
export TMPDIR="$PWD/tmp"
mkdir -p "$TCC_DARWIN_CACHE_DIR" "$TMPDIR"

cat > work/build/gcc/as <<SH_AS
#! /bin/sh
set -eu
compiler="$phase34/bin/tcc-darwin-cc"
awk_filter="$awk_filter"
out=""
input=""
while test "\$#" -gt 0; do
  case "\$1" in
    -o) shift; out="\$1" ;;
    -arch) shift ;;
    -force_cpusubtype_ALL|-mmacosx-version-min=*|-march=*|-mtune=*|-Qy|-Qn|--32|--64) ;;
    -) input="-" ;;
    *.s|*.S) input="\$1" ;;
    *) ;;
  esac
  shift || true
done
if test -z "\$out"; then
  echo "bootstrap-as: missing -o" >&2
  exit 1
fi
tmpdir="\$(mktemp -d "\${TMPDIR:-/tmp}/bootstrap-as.XXXXXX")"
trap 'rm -rf "\$tmpdir"' EXIT HUP INT TERM
filtered="\$tmpdir/input.s"
if test -z "\$input" || test "\$input" = "-"; then
  cat > "\$tmpdir/source.s"
  input="\$tmpdir/source.s"
fi
awk -f "\$awk_filter" "\$input" > "\$filtered"
exec "\$compiler" -c "\$filtered" -o "\$out"
SH_AS
chmod +x work/build/gcc/as

if [ -n "$xgcc_wrapper_template" ]; then
  cp "$xgcc_wrapper_template" work/build/gcc/xgcc-bootstrap
  chmod +x work/build/gcc/xgcc-bootstrap
fi

libgcc_dir=work/build/x86_64-apple-darwin/libgcc
mkdir -p "$libgcc_dir/include"
cp work/src/libgcc/stdarg.h "$libgcc_dir/include/stdarg.h"
cp work/src/libgcc/fcntl.h "$libgcc_dir/include/fcntl.h"
find "$libgcc_dir" \( -name '*.o' -o -name '*.a' -o -name '*.dep' \) -print0 | xargs -0 rm -f

cd "$libgcc_dir"
export MACOSX_DEPLOYMENT_TARGET=10.6
target_cc="env GCC46_PHASE36_CC1=$PWD/../../gcc/cc1 GCC46_PHASE36_AS=$PWD/../../gcc/as GCC46_PHASE36_VERSION=$gcc_version $PWD/../../gcc/xgcc-bootstrap -isystem $phase34/include/tcc-darwin-bootstrap -isystem $PWD/include"
CC="$target_cc" \
CPP="$target_cc -E" \
AR="$AR" \
RANLIB="$RANLIB" \
NM="$PWD/../../gcc/nm" \
sh ../../../src/libgcc/configure \
  --cache-file=./config.cache \
  --prefix="$phase35" \
  --with-native-system-header-dir="$phase34/include/tcc-darwin-bootstrap" \
  --with-build-sysroot="$phase34/include/tcc-darwin-bootstrap" \
  --disable-bootstrap \
  --disable-shared \
  --disable-multilib \
  --disable-nls \
  --enable-languages=c \
  --program-transform-name=s,y,y, \
  --disable-option-checking \
  --with-target-subdir=x86_64-apple-darwin \
  --build=x86_64-unknown-darwin \
  --host=x86_64-apple-darwin \
  --target=x86_64-apple-darwin \
  --srcdir=../../../src/libgcc \
  > "$out/share/darwin-bootstrap/configure-libgcc.stdout" \
  2> "$out/share/darwin-bootstrap/configure-libgcc.stderr"
mkdir -p include
rm -f stdarg.h fcntl.h include/stdarg.h include/fcntl.h
cp ../../../src/libgcc/stdarg.h stdarg.h
cp ../../../src/libgcc/stdarg.h include/stdarg.h
cp ../../../src/libgcc/fcntl.h fcntl.h
cp ../../../src/libgcc/fcntl.h include/fcntl.h

make -j1 \
  MAKEINFO=true \
  CC="$target_cc" \
  CPP="$target_cc -E" \
  AR="$AR" \
  RANLIB="$RANLIB" \
  NM="$PWD/../../gcc/nm" \
  CFLAGS_FOR_TARGET="-O2 -fno-asynchronous-unwind-tables -fno-unwind-tables" \
  CXXFLAGS_FOR_TARGET="-O2 -fno-asynchronous-unwind-tables -fno-unwind-tables" \
  GOCFLAGS_FOR_TARGET="-O2 -fno-asynchronous-unwind-tables -fno-unwind-tables" \
  > "$out/share/darwin-bootstrap/make-all-target-libgcc.stdout" \
  2> "$out/share/darwin-bootstrap/make-all-target-libgcc.stderr"

test -s libgcc.a
test -s libgcov.a
for obj in _muldi3 "${eh_objects[@]}" "${soft_fp_objects[@]}"; do
  test "$(od -An -tx1 -N4 "$obj.o" | tr -d ' \n')" = "7f454c46"
done
"$cctools/bin/ar" t libgcc.a > "$out/share/darwin-bootstrap/libgcc.members"
"$cctools/bin/ar" t libgcov.a > "$out/share/darwin-bootstrap/libgcov.members"
for obj in "${eh_objects[@]}" "${soft_fp_objects[@]}"; do
  grep -q "^$obj.o$" "$out/share/darwin-bootstrap/libgcc.members"
done

cp libgcc.a libgcov.a "$out/lib/gcc/x86_64-apple-darwin/$gcc_version/"
mkdir -p "$out/lib/gcc/x86_64-apple-darwin/$gcc_version/libgcc-objects"
while IFS= read -r member; do
  case "$member" in
    *.o) cp "$member" "$out/lib/gcc/x86_64-apple-darwin/$gcc_version/libgcc-objects/" ;;
  esac
done < "$out/share/darwin-bootstrap/libgcc.members"
cp _muldi3.o \
  unwind-dw2.o unwind-dw2-fde-darwin.o unwind-sjlj.o unwind-c.o emutls.o \
  addtf3.o divtf3.o multf3.o fixtfdi.o extendsftf2.o trunctfdf2.o \
  "$out/share/darwin-bootstrap/"
