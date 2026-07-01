#!/bin/sh
## 42-tinycc-boot3-link — link tcc-boot3.o into the tcc-boot3 binary.
##
## Final boot-cycle link: tcc-boot3 (generation 4) is the compiler
## the tcc-darwin-cc wrapper (step 44) drives for all gcc-era
## compiles.  Link recipe as in steps 38/40, libc recompiled by
## tcc-boot2.
##
## Runs:     tcc-boot2 (built in step 40), elf64-to-m1 (step 30), M1
##           (step 12), hex2 (step 13), hex2-data-relocs (step 34);
##           host awk — trust boundary — M1 code/data splits; Apple
##           /usr/bin cp/dd/chmod/install/grep/od/tr.
## Inputs:   target/share/tinycc-boot3-object/tcc-boot3.o (step 41),
##           sources/bootstrap-c/tinycc-sysv-libc.c and
##           tinycc-sysv-syscalls-amd64-darwin.M1,
##           sources/tinycc-fixtures/self-link-candidate-crt1-tcc-sysv.M1
##           and boot1-link-hello.c,
##           sources/stage0-posix/M2libc/amd64/MACHO-amd64-lowdata.hex2.
## Outputs:  target/bin/tcc-boot3.
## Verifies: smoke run — `tcc-boot3 -version` prints the pinned
##           string and `tcc-boot3 -c hello.c` emits an ELF object.
##           The boot cycle checks each generation by smoke run; no
##           step byte-compares successive generations' objects.
## Trust:    host awk for the M1 code/data splits.
set -eu

work="$TARGET/work/tinycc-boot3-link"
rm -rf "$work"
mkdir -p "$work"
cd "$work"

tcc-boot2 -c "$SOURCES/bootstrap-c/tinycc-sysv-libc.c" -o tinycc-sysv-libc.o \
    > tinycc-sysv-libc.stdout 2> tinycc-sysv-libc.stderr

elf64-to-m1 --prefix tinycc_sysv_libc_ \
    tinycc-sysv-libc.o tinycc-sysv-libc.M1

elf64-to-m1 --prefix tcc_boot3_ \
    "$TARGET/share/tinycc-boot3-object/tcc-boot3.o" \
    tcc-boot3.M1

cp "$SOURCES/tinycc-fixtures/self-link-candidate-crt1-tcc-sysv.M1" crt1-tcc-sysv.M1

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
    emit_code tcc-boot3.M1
    emit_code tinycc-sysv-libc.M1
    echo ':ELF_data'
    echo ':HEX2_data'
    emit_data tcc-boot3.M1
    emit_data tinycc-sysv-libc.M1
} > tcc-boot3-combined.M1

M1 --architecture amd64 --little-endian \
    -f tcc-boot3-combined.M1 \
    -o tcc-boot3.hex2

hex2 --architecture amd64 --little-endian \
    --base-address 0x1000000 \
    -f "$SOURCES/stage0-posix/M2libc/amd64/MACHO-amd64-lowdata.hex2" \
    -f tcc-boot3.hex2 \
    -o tcc-boot3

hex2-data-relocs patch tcc-boot3.hex2 tcc-boot3

dd if=/dev/zero of=tcc-boot3 bs=1 count=1 seek=41943039 conv=notrunc 2>/dev/null || true
chmod +x tcc-boot3
install tcc-boot3 "$TARGET/bin/tcc-boot3"

## Smoke test: -version and -c hello.c
"$TARGET/bin/tcc-boot3" -version > tcc-boot3-version.stdout 2> tcc-boot3-version.stderr
grep -q '0.9.28-darwin-bootstrap' tcc-boot3-version.stdout

cp "$SOURCES/tinycc-fixtures/boot1-link-hello.c" hello.c
"$TARGET/bin/tcc-boot3" -c hello.c -o hello.o > hello-c.stdout 2> hello-c.stderr
test "$(od -An -tx1 -N4 hello.o | tr -d ' \n')" = "7f454c46"
