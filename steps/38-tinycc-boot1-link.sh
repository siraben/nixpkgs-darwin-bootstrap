#!/bin/sh
## 38-tinycc-boot1-link — link tcc-boot1.o into tcc-boot1 binary.
set -eu

work="$TARGET/work/tinycc-boot1-link"
rm -rf "$work"
mkdir -p "$work"
cd "$work"

tcc-self -c "$SOURCES/bootstrap-c/tinycc-sysv-libc.c" -o tinycc-sysv-libc.o \
    > tinycc-sysv-libc.stdout 2> tinycc-sysv-libc.stderr

elf64-to-m1 --prefix tinycc_sysv_libc_ \
    tinycc-sysv-libc.o tinycc-sysv-libc.M1

elf64-to-m1 --prefix tcc_boot1_ \
    "$TARGET/share/tinycc-boot1-object/tcc-boot1.o" \
    tcc-boot1.M1

cp "$SOURCES/tinycc-fixtures/boot1-link-crt1-tcc-sysv.M1" crt1-tcc-sysv.M1

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
    cat "$SOURCES/bootstrap-c/tinycc-sysv-syscalls-amd64-darwin.M1"
    emit_code tcc-boot1.M1
    emit_code tinycc-sysv-libc.M1
    echo ':ELF_data'
    echo ':HEX2_data'
    emit_data tcc-boot1.M1
    emit_data tinycc-sysv-libc.M1
} > tcc-boot1-combined.M1

M1 --architecture amd64 --little-endian \
    -f tcc-boot1-combined.M1 \
    -o tcc-boot1.hex2

hex2 --architecture amd64 --little-endian \
    --base-address 0x1000000 \
    -f "$SOURCES/stage0-posix/M2libc/amd64/MACHO-amd64-lowdata.hex2" \
    -f tcc-boot1.hex2 \
    -o tcc-boot1

hex2-data-relocs patch tcc-boot1.hex2 tcc-boot1

dd if=/dev/zero of=tcc-boot1 bs=1 count=1 seek=41943039 conv=notrunc 2>/dev/null || true
chmod +x tcc-boot1
install tcc-boot1 "$TARGET/bin/tcc-boot1"

## Smoke test: -version and -c hello.c
"$TARGET/bin/tcc-boot1" -version > tcc-boot1-version.stdout 2> tcc-boot1-version.stderr
grep -q '0.9.28-darwin-bootstrap' tcc-boot1-version.stdout

cp "$SOURCES/tinycc-fixtures/boot1-link-hello.c" hello.c
"$TARGET/bin/tcc-boot1" -c hello.c -o hello.o > hello-c.stdout 2> hello-c.stderr
test "$(od -An -tx1 -N4 hello.o | tr -d ' \n')" = "7f454c46"
