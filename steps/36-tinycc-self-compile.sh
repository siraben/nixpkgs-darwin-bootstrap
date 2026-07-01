#!/bin/sh
## 36-tinycc-self-compile — verify tcc-self compiles and links a
## working hello binary.
##
## Self-hosting property established: the self-built compiler
## produces working executables — the step-31 detour test repeated
## with tcc-self in place of tcc, so generation 1's code generation
## is trusted before it compiles generation 2 (step 37).
##
## Runs:     tcc-self (built in step 35), elf64-to-m1 (step 30), M1
##           (step 12), hex2 (step 13), hex2-data-relocs (step 34);
##           host awk — trust boundary — M1 code/data split; Apple
##           /usr/bin cp/od/tr/dd/chmod for orchestration.
## Inputs:   sources/tinycc-fixtures/self-compile-hello.c and
##           self-compile-crt1-tcc-sysv.M1,
##           sources/stage0-posix/M2libc/amd64/MACHO-amd64-lowdata.hex2.
## Outputs:  none installed; scratch hello binary under
##           target/work/tinycc-self-compile.
## Verifies: tcc-self -c is silent, hello.o has the ELF magic, and
##           ./hello exits 42.
## Trust:    host awk for the M1 code/data split.
set -eu

work="$TARGET/work/tinycc-self-compile"
rm -rf "$work"
mkdir -p "$work"
cd "$work"

cp "$SOURCES/tinycc-fixtures/self-compile-hello.c" hello.c

tcc-self -c hello.c -o hello.o > hello-c.stdout 2> hello-c.stderr
test ! -s hello-c.stderr
test "$(od -An -tx1 -N4 hello.o | tr -d ' \n')" = "7f454c46"

elf64-to-m1 --prefix hello_ hello.o hello-object.M1

cp "$SOURCES/tinycc-fixtures/self-compile-crt1-tcc-sysv.M1" crt1-tcc-sysv.M1
{
    cat crt1-tcc-sysv.M1
    awk '
      /^:ELF_data$/ { data = 1; next }
      /^:HEX2_data$/ { next }
      data != 1 { print }
    ' hello-object.M1
    echo ':ELF_data'
    echo ':HEX2_data'
    awk '
      /^:ELF_data$/ { data = 1; next }
      /^:HEX2_data$/ { next }
      data == 1 { print }
    ' hello-object.M1
} > hello-combined.M1

M1 --architecture amd64 --little-endian \
    -f hello-combined.M1 \
    -o hello.hex2

hex2 --architecture amd64 --little-endian \
    --base-address 0x1000000 \
    -f "$SOURCES/stage0-posix/M2libc/amd64/MACHO-amd64-lowdata.hex2" \
    -f hello.hex2 \
    -o hello

hex2-data-relocs patch hello.hex2 hello

dd if=/dev/zero of=hello bs=1 count=1 seek=41943039 conv=notrunc 2>/dev/null || true
chmod +x hello

set +e
./hello
status="$?"
set -e
if [ "$status" -ne 42 ]; then
    echo "hello returned $status, expected 42" >&2
    exit 1
fi
