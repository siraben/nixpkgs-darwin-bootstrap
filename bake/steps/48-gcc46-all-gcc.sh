#!/bin/sh
## 48-gcc46-all-gcc — build gcc-4.6's all-gcc (xgcc + cc1) via tcc-darwin-cc.
##
## This is the big one — 30+ min build that produces a usable gcc front-end
## that can compile C source via tcc's codegen.
set -eu

src_in="$TARGET/gcc46-darwin-bootstrap-src"
out="$TARGET/gcc46-all-gcc"
test -d "$src_in" || { echo "missing $src_in" >&2; exit 1; }

rm -rf "$out"
mkdir -p "$out/bin" "$out/share/darwin-bootstrap"

work="$TARGET/work/gcc46-all-gcc"
rm -rf "$work"
mkdir -p "$work/src"
cd "$work"

cp -R "$src_in/." src/
chmod -R u+w src

## Replace /usr/include with our tcc bootstrap include dir
/usr/bin/perl -i -pe \
    's|^NATIVE_SYSTEM_HEADER_DIR = /usr/include|NATIVE_SYSTEM_HEADER_DIR = '"$TARGET/tcc-darwin-cc-root/include/tcc-darwin-bootstrap"'|' \
    src/gcc/Makefile.in

## prepare-source script
/bin/bash "$SOURCES/gcc46-scripts/phase35-prepare-source.sh"

CC="$TARGET/bin/tcc-darwin-cc"
CPP="$CC -E"
AR=/usr/bin/ar
NM=/usr/bin/nm
RANLIB=/usr/bin/ranlib
STRIP=/usr/bin/strip
LIPO=/usr/bin/lipo
OTOOL=/usr/bin/otool

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

## Install config caches to skip autoconf probes
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

## Configure (this is slow — multiple sub-configures)
echo "== running gcc-4.6 configure (slow, ~5-10 min) =="
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
    --enable-languages=c \
    MAKEINFO=true \
    > "$out/share/darwin-bootstrap/configure.stdout" \
    2> "$out/share/darwin-bootstrap/configure.stderr"

{
    echo '#include "bconfig.h"'
    cat ../src/gcc/gengtype-lex.c
} > gcc/gengtype-lex.c
touch gcc/gengtype-lex.c

## Make
echo "== running gcc-4.6 make all-gcc (slow, ~30 min) =="
"$TARGET/bin/make" all-gcc -j1 \
    MAKEINFO=true \
    NATIVE_SYSTEM_HEADER_DIR="$TARGET/tcc-darwin-cc-root/include/tcc-darwin-bootstrap" \
    CPP="$CPP" AR="$AR" NM="$NM" RANLIB="$RANLIB" STRIP="$STRIP" LIPO="$LIPO" OTOOL="$OTOOL" \
    > "$out/share/darwin-bootstrap/make-all-gcc.stdout" \
    2> "$out/share/darwin-bootstrap/make-all-gcc.stderr"

test -x gcc/xgcc
test -x gcc/cc1
./gcc/xgcc -B"$PWD/gcc/" --version > "$out/share/darwin-bootstrap/xgcc-version.stdout"

cp gcc/xgcc "$out/bin/xgcc"
mkdir -p "$out/share/darwin-bootstrap/work"
cp -R ../src "$out/share/darwin-bootstrap/work/src"
cp -R ../build "$out/share/darwin-bootstrap/work/build"

echo "gcc46-all-gcc complete; xgcc version:"
cat "$out/share/darwin-bootstrap/xgcc-version.stdout"
