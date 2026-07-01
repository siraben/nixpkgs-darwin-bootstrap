#!/bin/sh
## 39-tinycc-boot2-object — tcc-boot1 compiles tinycc → tcc-boot2.o.
##
## Third self-compile pass (generation 3 object).  Same source tree
## and -D set as steps 23/29/37; only the producing compiler changes
## (tcc-boot1, itself built by tcc-self).
##
## Runs:     tcc-boot1 (built in step 38); Apple /usr/bin cp/chmod/
##           od/tr/install for orchestration and checks.
## Inputs:   target/tinycc-mes-src/tcc.c + include/ (step 22),
##           target/mes-source/include (step 15) — merged include
##           dir as in step 29.
## Outputs:  target/share/tinycc-boot2-object/tcc-boot2.o.
## Verifies: tcc-boot2.o has the ELF magic and the compile produced
##           no stdout.
## Trust:    none beyond prior chain outputs.
set -eu

mes_source="$TARGET/mes-source"
tinycc_src="$TARGET/tinycc-mes-src"
work="$TARGET/work/tinycc-boot2-object"
rm -rf "$work"
mkdir -p "$work/include"
cd "$work"

cp -R "$mes_source/include/." include/
chmod -R u+w include
cp -R "$tinycc_src/include/." include/

tcc-boot1 -c \
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
  -o tcc-boot2.o \
  > tcc-boot2.stdout 2> tcc-boot2.stderr

test "$(od -An -tx1 -N4 tcc-boot2.o | tr -d ' \n')" = "7f454c46"
test ! -s tcc-boot2.stdout

install -d "$TARGET/share/tinycc-boot2-object"
cp tcc-boot2.o "$TARGET/share/tinycc-boot2-object/"
