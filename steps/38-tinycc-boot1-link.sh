#!/bin/sh
## 38-tinycc-boot1-link — link tcc-boot1.o into the tcc-boot1 binary.
##
## Self-hosting property established: generation 2 runs.  The link
## recipe matches step 35, with the libc also recompiled by tcc-self
## so compiler and libc come from the same generation.
##
## Runs:     tcc-self (built in step 35), elf64-to-m1 (step 30), M1
##           (step 12), hex2 (step 13), hex2-data-relocs (step 34);
##           host awk — trust boundary — M1 code/data splits; Apple
##           /usr/bin cp/dd/chmod/install/grep/od/tr.
## Inputs:   target/share/tinycc-boot1-object/tcc-boot1.o (step 37),
##           sources/bootstrap-c/tinycc-sysv-libc.c and
##           tinycc-sysv-syscalls-amd64-darwin.M1,
##           sources/tinycc-fixtures/boot1-link-crt1-tcc-sysv.M1 and
##           boot1-link-hello.c,
##           sources/stage0-posix/M2libc/amd64/MACHO-amd64-lowdata.hex2.
## Outputs:  target/bin/tcc-boot1.
## Verifies: smoke run — `tcc-boot1 -version` prints the pinned
##           string and `tcc-boot1 -c hello.c` emits an ELF object.
## Trust:    host awk for the M1 code/data splits.
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
