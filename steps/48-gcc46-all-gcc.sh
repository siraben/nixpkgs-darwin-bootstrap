#!/bin/sh
## 48-gcc46-all-gcc — build gcc-4.6's all-gcc (xgcc + cc1) via tcc-darwin-cc.
##
## This is the big one — 30+ min build that produces a usable gcc front-end.
## `make all-gcc` builds the compiler proper (driver xgcc, C front-end cc1,
## the gen* generator programs, libiberty, in-tree gmp/mpfr/mpc) with every
## object compiled and linked by the chain tcc; target libgcc is deferred
## to step 49.  cc1 is the first optimizing C compiler in the chain and the
## stepping stone to the C++-implemented gcc-10.
##
## Runs:    chain tcc-darwin-cc from step 44 (CC/CXX/CPP/CC_FOR_BUILD —
##          all compilation, preprocessing, and linking);
##          chain make from step 45;
##          chain boot-ar from step 44b via scripts/boot-ar, and the no-op
##          scripts/boot-ranlib;
##          host /usr/bin/perl for one Makefile.in text edit — trust
##          boundary (text edit only);
##          chain boot-patch from step 14b for the committed
##          prepare-source patch;
##          Apple nm/strip/lipo/otool (inspection roles wired into
##          configure; no code generation) and Apple sh/tar/install for
##          orchestration.  phase35-prepare-source.sh (symlink to
##          nix/scripts/gcc-4.6/prepare-source.sh) performs fixed source
##          edits and applies a committed patch via $GNUPATCH.
## Inputs:  $TARGET/gcc46-darwin-bootstrap-src (step 47);
##          $TARGET/tcc-darwin-cc-root/include/tcc-darwin-bootstrap (the
##          chain libc headers, used as the native system header dir and
##          build sysroot so host /usr/include is never read);
##          sources/gcc46-fixtures/*.cache (committed configure caches).
## Outputs: $TARGET/gcc46-all-gcc/bin/xgcc;
##          $TARGET/gcc46-all-gcc/share/darwin-bootstrap/work/{src,build}
##          (full source + build trees, reused by steps 49 and 50);
##          configure/make logs under share/darwin-bootstrap/.
## Verifies: gcc/xgcc and gcc/cc1 exist and are executable; xgcc runs and
##          reports its version (Mach-O produced by the chain executes).
## Trust:   translation is chain-only (tcc compiles, boot-ar archives,
##          tcc-darwin-cc links); host tools do text edits + inspection.
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

## Replace /usr/include with our tcc bootstrap include dir (host perl,
## trust boundary: a one-line Makefile.in text substitution).
/usr/bin/perl -i -pe \
    's|^NATIVE_SYSTEM_HEADER_DIR = /usr/include|NATIVE_SYSTEM_HEADER_DIR = '"$TARGET/tcc-darwin-cc-root/include/tcc-darwin-bootstrap"'|' \
    src/gcc/Makefile.in

## prepare-source script: deterministic gcc/gmp source edits (deployment-
## target driver block, gen-bases libm removal, GMP doc stub + NULL macro)
## shared with the Nix track.  The script applies a committed patch via
## chain-built boot-patch.
GNUPATCH="$TARGET/bin/boot-patch" \
PREPARE_SOURCE_PATCH="$SOURCES/gcc46-patches/prepare-source.patch" \
/bin/bash "$SOURCES/gcc46-scripts/phase35-prepare-source.sh"

CC="$TARGET/bin/tcc-darwin-cc"
CPP="$CC -E"
## Apple's /usr/bin/ar refuses our ELF objects (it warns "not a mach-o
## file" and produces an empty archive); use the ELF-capable boot-ar and
## a no-op ranlib (tcc-darwin-cc indexes archive members itself).
AR="$ROOT/scripts/boot-ar"
NM=/usr/bin/nm
RANLIB="$ROOT/scripts/boot-ranlib"
STRIP=/usr/bin/strip
LIPO=/usr/bin/lipo
OTOOL=/usr/bin/otool

## Byte collation so gcc's .opt dedup (adjacent identical option names)
## works; a UTF-8 locale separates them and yields duplicate OPT_*
## enumerators in the generated options.h.
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
## The chain libc has no getrlimit/setrlimit; pre-answer the configure
## probes so gcc's host-side code takes its no-rlimit paths.
export ac_cv_have_decl_getrlimit=no
export ac_cv_have_decl_setrlimit=no
export ac_cv_func_getrlimit=no
export ac_cv_func_setrlimit=no

mkdir -p build
cd build

## Install committed config caches to skip autoconf probes.  Every
## compile-and-link conftest goes through the chain tcc-darwin-cc Mach-O
## link path, so probing from scratch is slow; the caches pin the answers
## appropriate for the chain libc.
mkdir -p gcc
install -m644 "$SOURCES/gcc46-fixtures/all-gcc-gcc-config.cache" gcc/config.cache
## Pin the gcc_cv_have_decl_* probes to "no": gcc's system.h then supplies
## its own declarations instead of trusting the minimal chain headers.
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

## Pre-place the shipped flex output for gengtype-lex in the build dir
## with #include "bconfig.h" prepended (the Makefile normally prepends it
## while regenerating from gengtype-lex.l; flex is absent from the chain
## PATH).  touch makes it newer than the .l so make skips the flex rule.
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
