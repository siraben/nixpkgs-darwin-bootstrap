#!/bin/sh
## 51-gcc46-cxx-all-gcc — build gcc-4.6 with C AND C++ front-ends
## (cc1 + cc1plus + xgcc) via tcc-darwin-cc.
##
## gcc-4.6 is itself written in C (GCC went C++-only in 4.8), so cc1plus
## compiles from C sources via tcc exactly like cc1 — this reuses the
## proven step-48 path with --enable-languages=c,c++.  This is the
## prerequisite for building libstdc++ and then gcc-10 (which is C++).
set -eu

src_in="$TARGET/gcc46-darwin-bootstrap-src"
out="$TARGET/gcc46-cxx-all-gcc"
test -d "$src_in" || { echo "missing $src_in (run 47 first)" >&2; exit 1; }

rm -rf "$out"
mkdir -p "$out/bin" "$out/share/darwin-bootstrap"

work="$TARGET/work/gcc46-cxx-all-gcc"
rm -rf "$work"
mkdir -p "$work/src"
cd "$work"

cp -R "$src_in/." src/
chmod -R u+w src

/usr/bin/perl -i -pe \
    's|^NATIVE_SYSTEM_HEADER_DIR = /usr/include|NATIVE_SYSTEM_HEADER_DIR = '"$TARGET/tcc-darwin-cc-root/include/tcc-darwin-bootstrap"'|' \
    src/gcc/Makefile.in

/bin/bash "$SOURCES/gcc46-scripts/phase35-prepare-source.sh"

CC="$TARGET/bin/tcc-darwin-cc"
CPP="$CC -E"
AR="$ROOT/scripts/boot-ar"
NM=/usr/bin/nm
RANLIB="$ROOT/scripts/boot-ranlib"
STRIP=/usr/bin/strip
LIPO=/usr/bin/lipo
OTOOL=/usr/bin/otool

export LC_ALL=C LANG=C

export CC CPP AR NM RANLIB STRIP LIPO OTOOL
export CC_FOR_BUILD="$CC"
export CFLAGS="-g"
export CFLAGS_FOR_BUILD="-g"
export CXX="$CC"
export CXXCPP="$CC -E"
export MACOSX_DEPLOYMENT_TARGET=10.6
export TCC_DARWIN_CACHE_DIR="$work/.tcc-darwin-cache"
mkdir -p "$TCC_DARWIN_CACHE_DIR"
export ac_cv_have_decl_getrlimit=no
export ac_cv_have_decl_setrlimit=no
export ac_cv_func_getrlimit=no
export ac_cv_func_setrlimit=no

mkdir -p build
cd build

mkdir -p gcc
install -m644 "$SOURCES/gcc46-fixtures/all-gcc-gcc-config.cache" gcc/config.cache
for f in getenv atol asprintf sbrk abort atof getcwd getwd \
    strsignal strstr strverscmp errno snprintf vsnprintf vasprintf \
    malloc realloc calloc free basename getopt clock getpagesize \
    clearerr_unlocked feof_unlocked ferror_unlocked fflush_unlocked \
    fgetc_unlocked fgets_unlocked fileno_unlocked fprintf_unlocked \
    fputc_unlocked fputs_unlocked fread_unlocked fwrite_unlocked \
    getchar_unlocked getc_unlocked putchar_unlocked putc_unlocked; do
    printf 'gcc_cv_have_decl_%s=${gcc_cv_have_decl_%s=no}\n' "$f" "$f" >> gcc/config.cache
done

for d in libiberty build-x86_64-apple-darwin/libiberty; do
    mkdir -p "$d"
    install -m644 "$SOURCES/gcc46-fixtures/all-gcc-libiberty-config.cache" "$d/config.cache"
done
for d in mpfr mpc; do
    mkdir -p "$d"
    install -m644 "$SOURCES/gcc46-fixtures/all-gcc-mpfr-config.cache" "$d/config.cache"
done

echo "== running gcc-4.6 c,c++ configure (slow) =="
../src/configure \
    --prefix="$out" \
    --build=x86_64-apple-darwin \
    --host=x86_64-apple-darwin \
    --target=x86_64-apple-darwin \
    --with-native-system-header-dir="$TARGET/tcc-darwin-cc-root/include/tcc-darwin-bootstrap" \
    --with-build-sysroot="$TARGET/tcc-darwin-cc-root/include/tcc-darwin-bootstrap" \
    --disable-bootstrap \
    --disable-shared \
    --disable-multilib \
    --disable-nls \
    --enable-languages=c,c++ \
    MAKEINFO=true \
    > "$out/share/darwin-bootstrap/configure.stdout" \
    2> "$out/share/darwin-bootstrap/configure.stderr"

{
    echo '#include "bconfig.h"'
    cat ../src/gcc/gengtype-lex.c
} > gcc/gengtype-lex.c
touch gcc/gengtype-lex.c

echo "== running gcc-4.6 make all-gcc (c,c++) (slow) =="
"$TARGET/bin/make" all-gcc -j1 \
    MAKEINFO=true \
    NATIVE_SYSTEM_HEADER_DIR="$TARGET/tcc-darwin-cc-root/include/tcc-darwin-bootstrap" \
    CPP="$CPP" AR="$AR" NM="$NM" RANLIB="$RANLIB" STRIP="$STRIP" LIPO="$LIPO" OTOOL="$OTOOL" \
    > "$out/share/darwin-bootstrap/make-all-gcc.stdout" \
    2> "$out/share/darwin-bootstrap/make-all-gcc.stderr"

test -x gcc/xgcc
test -x gcc/cc1
test -x gcc/cc1plus
./gcc/xgcc -B"$PWD/gcc/" --version > "$out/share/darwin-bootstrap/xgcc-version.stdout"

cp gcc/xgcc "$out/bin/xgcc"
test -x gcc/g++ && cp gcc/g++ "$out/bin/g++" || true
mkdir -p "$out/share/darwin-bootstrap/work"
cp -R ../src "$out/share/darwin-bootstrap/work/src"
cp -R ../build "$out/share/darwin-bootstrap/work/build"

echo "gcc46-cxx-all-gcc complete; cc1plus built:"
ls -la gcc/cc1plus | awk '{print $5,$9}'
