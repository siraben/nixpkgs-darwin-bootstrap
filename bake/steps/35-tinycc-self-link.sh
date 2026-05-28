#!/bin/sh
## 35-tinycc-self-link — link the self-compiled tcc into a runnable
## tcc-self binary that has its own libc.
set -eu

work="$TARGET/work/tinycc-self-link"
rm -rf "$work"
mkdir -p "$work"
cd "$work"

tcc -c "$SOURCES/bootstrap-c/tinycc-sysv-libc.c" -o tinycc-sysv-libc.o \
    > tinycc-sysv-libc.stdout 2> tinycc-sysv-libc.stderr

elf64-to-m1 --prefix tinycc_sysv_libc_ \
    tinycc-sysv-libc.o \
    tinycc-sysv-libc.M1

cp "$SOURCES/tinycc-fixtures/self-link-crt1-tcc-sysv.M1" crt1-tcc-sysv.M1

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
    emit_code "$TARGET/share/tinycc-self-m1/tcc-from-elf.M1"
    emit_code tinycc-sysv-libc.M1
    echo ':ELF_data'
    echo ':HEX2_data'
    emit_data "$TARGET/share/tinycc-self-m1/tcc-from-elf.M1"
    emit_data tinycc-sysv-libc.M1
} > tcc-self-combined.M1

M1 --architecture amd64 --little-endian \
    -f tcc-self-combined.M1 \
    -o tcc-self.hex2

hex2 --architecture amd64 --little-endian \
    --base-address 0x1000000 \
    -f "$SOURCES/stage0-posix/M2libc/amd64/MACHO-amd64-lowdata.hex2" \
    -f tcc-self.hex2 \
    -o tcc-self

hex2-data-relocs patch tcc-self.hex2 tcc-self

dd if=/dev/zero of=tcc-self bs=1 count=1 seek=41943039 conv=notrunc 2>/dev/null || true
chmod +x tcc-self
install tcc-self "$TARGET/bin/tcc-self"

## Smoke test
"$TARGET/bin/tcc-self" -version > tcc-self-version.stdout 2> tcc-self-version.stderr
grep -q '0.9.28-darwin-bootstrap' tcc-self-version.stdout
test ! -s tcc-self-version.stderr
