#!/bin/sh
## 28-tinycc-compile — exercise tcc's -E preprocessor and -c compiler
## modes.  Sanity check that the seed-built tcc actually compiles C.
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

## hello.o is an ELF object (tcc is ELF-target, even on Darwin):
test "$(od -An -tx1 -N4 hello.o | tr -d ' \n')" = "7f454c46"
