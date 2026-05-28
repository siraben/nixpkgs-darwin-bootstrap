#!/bin/sh
## 33-tinycc-sysv-libc — two-file linking test: hello.c + strlen.c
## linked into a single Mach-O.  Verifies tcc's multi-object linking.
set -eu

work="$TARGET/work/tinycc-sysv-libc"
rm -rf "$work"
mkdir -p "$work"
cd "$work"

cp "$SOURCES/tinycc-fixtures/sysv-libc-hello.c" hello.c
cp "$SOURCES/tinycc-fixtures/sysv-libc-strlen.c" strlen.c

tcc -c hello.c -o hello.o > hello-c.stdout 2> hello-c.stderr
tcc -c strlen.c -o strlen.o > strlen-c.stdout 2> strlen-c.stderr
test ! -s hello-c.stderr
test ! -s strlen-c.stderr

elf64-to-m1 --prefix hello_ hello.o hello-object.M1
elf64-to-m1 --prefix strlen_ strlen.o strlen-object.M1

cp "$SOURCES/tinycc-fixtures/sysv-libc-crt1-tcc-sysv.M1" crt1-tcc-sysv.M1

emit_code() {
    awk '
      /^:ELF_data$/ { data = 1; next }
      /^:HEX2_data$/ { next }
      data != 1 { print }
    ' "$1"
}
emit_data() {
    awk '
      /^:ELF_data$/ { data = 1; next }
      /^:HEX2_data$/ { next }
      data == 1 { print }
    ' "$1"
}

{
    cat crt1-tcc-sysv.M1
    emit_code hello-object.M1
    emit_code strlen-object.M1
    echo ':ELF_data'
    echo ':HEX2_data'
    emit_data hello-object.M1
    emit_data strlen-object.M1
} > hello-combined.M1

M1 --architecture amd64 --little-endian \
    -f hello-combined.M1 \
    -o hello.hex2

hex2 --architecture amd64 --little-endian \
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
if [ "$status" -ne 9 ]; then
    echo "hello returned $status, expected 9" >&2
    exit 1
fi
