#!/bin/sh
## 37-tinycc-boot1-object — use tcc-self to compile tinycc again,
## producing tcc-boot1.o.  This is the second self-compile pass —
## proves the tinycc bootstrap is stable.
set -eu

mes_source="$TARGET/mes-source"
tinycc_src="$TARGET/tinycc-mes-src"
work="$TARGET/work/tinycc-boot1-object"
rm -rf "$work"
mkdir -p "$work/include"
cd "$work"

cp -R "$mes_source/include/." include/
chmod -R u+w include
cp -R "$tinycc_src/include/." include/

tcc-self -c \
  -I"$PWD/include" \
  -DBOOTSTRAP=1 \
  -DHAVE_LONG_LONG=1 \
  -DTCC_TARGET_X86_64=1 \
  -Dinline= \
  -D'CONFIG_TCCDIR=""' \
  -D'CONFIG_SYSROOT=""' \
  -D'CONFIG_TCC_CRTPREFIX="{B}"' \
  -D'CONFIG_TCC_ELFINTERP="/mes/loader"' \
  -D'CONFIG_TCC_LIBPATHS="{B}"' \
  -D'TCC_LIBGCC="libc.a"' \
  -D'TCC_LIBTCC1="libtcc1.a"' \
  -DCONFIG_TCC_LIBTCC1_MES=0 \
  -DCONFIG_TCCBOOT=1 \
  -DCONFIG_TCC_STATIC=1 \
  -DCONFIG_USE_LIBGCC=1 \
  -DTCC_MES_LIBC=1 \
  -D'TCC_VERSION="0.9.28-darwin-bootstrap"' \
  -DONE_SOURCE=1 \
  "$tinycc_src/tcc.c" \
  -o tcc-boot1.o \
  > tcc-boot1.stdout 2> tcc-boot1.stderr

test "$(od -An -tx1 -N4 tcc-boot1.o | tr -d ' \n')" = "7f454c46"
test ! -s tcc-boot1.stdout

install -d "$TARGET/share/tinycc-boot1-object"
cp tcc-boot1.o "$TARGET/share/tinycc-boot1-object/"
