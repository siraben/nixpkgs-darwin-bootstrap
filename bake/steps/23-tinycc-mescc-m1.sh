#!/bin/sh
## 23-tinycc-mescc-m1 — compile tcc.c through mescc.scm to tcc.M1.
## This is the first step of the tinycc bootstrap chain.
##
## Uses ONE_SOURCE=1 mode (compile all of tinycc from a single
## #include'ed tcc.c file).
set -eu

mes_source="$TARGET/mes-source"
nyacc_dir="$TARGET/nyacc/share/nyacc-1.09.1"
tinycc_src="$TARGET/tinycc-mes-src"
work="$TARGET/work/tinycc-mescc-m1"
rm -rf "$work"
mkdir -p "$work"
cd "$work"

mesLoadPath="$mes_source/module:$mes_source/mes/module:$nyacc_dir/module"

MES_PREFIX="$mes_source" \
    GUILE_LOAD_PATH="$mesLoadPath" \
    MES_STACK=12000000 \
    MES_ARENA=140000000 \
    MES_MAX_ARENA=140000000 \
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
sed -i.bak '/^<$/d' tcc.M1
rm -f tcc.M1.bak
grep -q '^:main' tcc.M1

install -d "$TARGET/share/tinycc-mescc-m1"
cp tcc.M1 tcc-mescc.stdout tcc-mescc.stderr "$TARGET/share/tinycc-mescc-m1/"
