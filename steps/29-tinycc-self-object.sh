#!/bin/sh
## 29-tinycc-self-object — use the mescc-built tcc to compile its own
## source (tcc.c via ONE_SOURCE) into an ELF object tcc.o.
##
## Self-hosting property established: tcc compiles the full tinycc C
## source (its own).  Linking that object into a runnable binary is
## deferred to step 35, after the elf64-to-m1 detour (steps 30–32)
## and the data-relocs patcher (step 34) exist.  The -D set matches
## step 23 exactly, so the self-compiled compiler has the same
## configuration as the mescc-compiled one.
##
## Runs:     tcc (built in step 27); Apple /usr/bin cp/chmod/od/tr/
##           grep/install for orchestration and checks.
## Inputs:   target/tinycc-mes-src/tcc.c + include/ (step 22),
##           target/mes-source/include (step 15) — merged into one
##           include dir, tinycc's headers copied over mes's.
## Outputs:  target/share/tinycc-self-object/tcc.o (ELF64
##           relocatable).
## Verifies: tcc.o starts with the ELF magic; stderr contains the
##           expected implicit-declaration warnings (the minimal
##           headers lack some prototypes) — a pinned expectation, so
##           a silent or differently-failing compile is caught.
## Trust:    none beyond prior chain outputs.
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
