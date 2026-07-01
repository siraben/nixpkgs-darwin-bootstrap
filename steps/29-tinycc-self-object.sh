#!/bin/sh
## 29-tinycc-self-object — use the mescc-built tcc to compile its own
## source (tcc.c via ONE_SOURCE) into an ELF object tcc.o.
##
## Verifies that the bootstrap tcc can successfully compile the full
## tinycc C source even though it can't yet link a runnable binary.
set -eu

mes_source="$TARGET/mes-source"
tinycc_src="$TARGET/tinycc-mes-src"
work="$TARGET/work/tinycc-self-object"
rm -rf "$work"
mkdir -p "$work/include"
cd "$work"

cp -R "$mes_source/include/." include/
chmod -R u+w include
cp -R "$tinycc_src/include/." include/

tcc -c \
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
  -o tcc.o \
  > tcc-self.stdout 2> tcc-self.stderr

## Verify object is ELF
test "$(od -An -tx1 -N4 tcc.o | tr -d ' \n')" = "7f454c46"
## Expected: some implicit-declaration warnings since headers are minimal
grep -q 'implicit declaration of function' tcc-self.stderr

install -d "$TARGET/share/tinycc-self-object"
cp tcc.o "$TARGET/share/tinycc-self-object/"
