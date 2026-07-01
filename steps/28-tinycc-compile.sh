#!/bin/sh
## 28-tinycc-compile — exercise tcc's -E preprocessor and -c compiler
## modes.  Sanity check that the seed-built tcc actually compiles C.
##
## Self-hosting property established: the step-27 tcc functions as a
## compiler on real input — preprocessing works and -c emits an ELF64
## relocatable object.  The boot cycle depends on both before feeding
## tcc its own full source in step 29.
##
## Runs:     tcc (built in step 27); Apple /usr/bin cp/grep/od/tr for
##           orchestration and checks.
## Inputs:   sources/tinycc-fixtures/compile-hello.c.
## Outputs:  none installed; scratch files under
##           target/work/tinycc-compile only.
## Verifies: -E output contains the source text with empty stderr;
##           -c is silent and hello.o starts with the ELF magic
##           7f 45 4c 46.
## Trust:    none beyond prior chain outputs.
set -eu

work="$TARGET/work/tinycc-compile"
rm -rf "$work"
mkdir -p "$work"
cd "$work"

cp "$SOURCES/tinycc-fixtures/compile-hello.c" hello.c

tcc -E hello.c > hello.i 2> hello-E.stderr
grep -q 'return 42' hello.i
test ! -s hello-E.stderr

tcc -c hello.c -o hello.o > hello-c.stdout 2> hello-c.stderr
test ! -s hello-c.stdout
test ! -s hello-c.stderr

## hello.o is an ELF object: this tcc targets x86_64 ELF even on
## Darwin.  Mach-O executables come from the elf64-to-m1 detour
## (steps 30–31): ELF .o → M1 text → hex2 → Mach-O.
test "$(od -An -tx1 -N4 hello.o | tr -d ' \n')" = "7f454c46"
