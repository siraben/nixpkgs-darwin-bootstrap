#!/bin/sh
## 31-tinycc-elf-to-macho — convert tcc-compiled ELF .o → Mach-O via
## elf64-to-m1 + M1 + hex2 + macho-patcher.
##
## Mirrors tinycc/elf-to-macho.nix.  Builds and runs hello binary
## with exit code 42.
set -eu

work="$TARGET/work/tinycc-elf-to-macho"
rm -rf "$work"
mkdir -p "$work"
cd "$work"

cp "$SOURCES/tinycc-fixtures/elf-to-macho-hello.c" hello.c

tcc -c hello.c -o hello.o > hello-c.stdout 2> hello-c.stderr
test ! -s hello-c.stdout
test ! -s hello-c.stderr
test "$(od -An -tx1 -N4 hello.o | tr -d ' \n')" = "7f454c46"

elf64-to-m1 --prefix hello_ hello.o hello-object.M1

cp "$SOURCES/tinycc-fixtures/elf-to-macho-crt1-tcc-sysv.M1" crt1-tcc-sysv.M1
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

M1 \
  --architecture amd64 \
  --little-endian \
  -f hello-combined.M1 \
  -o hello.hex2

hex2 \
  --architecture amd64 \
  --little-endian \
  --base-address 0x1000000 \
  -f "$SOURCES/stage0-posix/M2libc/amd64/MACHO-amd64-lowdata.hex2" \
  -f hello.hex2 \
  -o hello

macho-patcher m2-segments hello.hex2 hello

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
