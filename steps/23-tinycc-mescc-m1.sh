#!/bin/sh
## 23-tinycc-mescc-m1 — compile tcc.c through mescc.scm to tcc.M1.
## First step of the tinycc boot cycle.
##
## Self-hosting property established: the full tinycc source is
## compilable by the seed-derived toolchain — mescc (a C compiler
## written in Scheme) running on the chain-built mes interpreter emits
## tinycc as M1 assembly text, with no compiled C compiler involved.
##
## Uses ONE_SOURCE=1 mode (all of tinycc compiled from the single
## #include'ing tcc.c translation unit).  The -D set is the pinned
## bootstrap configuration; every later self-compile (steps 29, 37,
## 39, 41) passes the same defines so all generations are built from
## one configuration.
##
## Runs:     mes-m2 (built in step 18) interpreting mescc.scm
##           (installed in step 20) with nyacc modules (step 19);
##           Apple /usr/bin sed/grep/install/cp for orchestration.
##           M1/HEX2 env vars point at the chain M1 (step 12) and
##           hex2 (step 13) for mescc's tool hooks; with -S only the
##           M1 text is produced.
## Inputs:   target/tinycc-mes-src/ (step 22), target/mes-source
##           (step 15: headers + mescc support), target/nyacc
##           (step 19), target/share/mescc-trivial/mescc.scm (step 20).
## Outputs:  target/share/tinycc-mescc-m1/{tcc.M1,tcc-mescc.stdout,
##           tcc-mescc.stderr}.
## Verifies: tcc.M1 is non-empty and defines :main — the compile
##           reached the end of tcc.c and emitted the entry function.
## Trust:    none beyond prior chain outputs; sed only deletes stray
##           single-'<' lines from the emitted M1.
set -eu

mes_source="$TARGET/mes-source"
nyacc_dir="$TARGET/nyacc/share/nyacc-1.09.1"
tinycc_src="$TARGET/tinycc-mes-src"
work="$TARGET/work/tinycc-mescc-m1"
rm -rf "$work"
mkdir -p "$work"
cd "$work"

mesLoadPath="$mes_source/module:$mes_source/mes/module:$nyacc_dir/module"

## MES_STACK/MES_ARENA size the mes interpreter's cell stack and GC
## arena; compiling all of tinycc in one translation unit needs the
## large values.
MES_PREFIX="$mes_source" \
    GUILE_LOAD_PATH="$mesLoadPath" \
    MES_STACK=6000000 \
    MES_ARENA=60000000 \
    MES_MAX_ARENA=60000000 \
    srcdest="$mes_source/" \
    includedir="$mes_source/include" \
    libdir="$mes_source/lib" \
    M1="$TARGET/bin/M1" \
    HEX2="$TARGET/bin/hex2" \
    mes-m2 --no-auto-compile -e main \
      "$TARGET/share/mescc-trivial/mescc.scm" -- \
      -S \
      -o tcc.M1 \
      -I "$tinycc_src" \
      -I "$tinycc_src/include" \
      -I "$mes_source/include" \
      -D BOOTSTRAP=1 \
      -D HAVE_LONG_LONG=1 \
      -D TCC_TARGET_X86_64=1 \
      -D inline= \
      -D CONFIG_TCCDIR="\"\"" \
      -D CONFIG_SYSROOT="\"\"" \
      -D CONFIG_TCC_CRTPREFIX="\"{B}\"" \
      -D CONFIG_TCC_ELFINTERP="\"/mes/loader\"" \
      -D CONFIG_TCC_LIBPATHS="\"{B}\"" \
      -D CONFIG_TCC_SYSINCLUDEPATHS="\"$tinycc_src/include:$mes_source/include\"" \
      -D TCC_LIBGCC="\"libc.a\"" \
      -D TCC_LIBTCC1="\"libtcc1.a\"" \
      -D CONFIG_TCC_LIBTCC1_MES=0 \
      -D CONFIG_TCCBOOT=1 \
      -D CONFIG_TCC_STATIC=1 \
      -D CONFIG_USE_LIBGCC=1 \
      -D TCC_MES_LIBC=1 \
      -D TCC_VERSION="\"0.9.28-darwin-bootstrap\"" \
      -D ONE_SOURCE=1 \
      "$tinycc_src/tcc.c" \
    > tcc-mescc.stdout 2> tcc-mescc.stderr

test -s tcc.M1
## Drop lines consisting of a single '<' — stray interpreter output
## interleaved into the M1 stream.
sed -i.bak '/^<$/d' tcc.M1
rm -f tcc.M1.bak
grep -q '^:main' tcc.M1

install -d "$TARGET/share/tinycc-mescc-m1"
cp tcc.M1 tcc-mescc.stdout tcc-mescc.stderr "$TARGET/share/tinycc-mescc-m1/"
