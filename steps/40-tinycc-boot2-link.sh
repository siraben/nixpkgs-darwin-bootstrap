#!/bin/sh
## 40-tinycc-boot2-link — link tcc-boot2.o into the tcc-boot2 binary.
##
## Self-hosting property established: generation 3 runs.  Link recipe
## as in step 38, with the libc recompiled by tcc-boot1.
##
## Runs:     tcc-boot1 (built in step 38), elf64-to-m1 (step 30), M1
##           (step 12), hex2 (step 13), hex2-data-relocs (step 34);
##           host awk — trust boundary — M1 code/data splits; Apple
##           /usr/bin cp/dd/chmod/install/grep/od/tr.
## Inputs:   target/share/tinycc-boot2-object/tcc-boot2.o (step 39),
##           sources/bootstrap-c/tinycc-sysv-libc.c and
##           tinycc-sysv-syscalls-amd64-darwin.M1,
##           sources/tinycc-fixtures/self-link-candidate-crt1-tcc-sysv.M1
##           and boot1-link-hello.c,
##           sources/stage0-posix/M2libc/amd64/MACHO-amd64-lowdata.hex2.
## Outputs:  target/bin/tcc-boot2.
## Verifies: smoke run — `tcc-boot2 -version` prints the pinned
##           string and `tcc-boot2 -c hello.c` emits an ELF object.
## Trust:    host awk for the M1 code/data splits.
set -eu

work="$TARGET/work/tinycc-boot2-link"
rm -rf "$work"
mkdir -p "$work"
cd "$work"

tcc-boot1 -c "$SOURCES/bootstrap-c/tinycc-sysv-libc.c" -o tinycc-sysv-libc.o \
    > tinycc-sysv-libc.stdout 2> tinycc-sysv-libc.stderr

elf64-to-m1 --prefix tinycc_sysv_libc_ \
    tinycc-sysv-libc.o tinycc-sysv-libc.M1

elf64-to-m1 --prefix tcc_boot2_ \
    "$TARGET/share/tinycc-boot2-object/tcc-boot2.o" \
    tcc-boot2.M1

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
    emit_code tcc-boot2.M1
    emit_code tinycc-sysv-libc.M1
    echo ':ELF_data'
    echo ':HEX2_data'
    emit_data tcc-boot2.M1
    emit_data tinycc-sysv-libc.M1
} > tcc-boot2-combined.M1

M1 --architecture amd64 --little-endian \
    -f tcc-boot2-combined.M1 \
    -o tcc-boot2.hex2

hex2 --architecture amd64 --little-endian \
    --base-address 0x1000000 \
    -f "$SOURCES/stage0-posix/M2libc/amd64/MACHO-amd64-lowdata.hex2" \
    -f tcc-boot2.hex2 \
    -o tcc-boot2

hex2-data-relocs patch tcc-boot2.hex2 tcc-boot2

dd if=/dev/zero of=tcc-boot2 bs=1 count=1 seek=41943039 conv=notrunc 2>/dev/null || true
chmod +x tcc-boot2
install tcc-boot2 "$TARGET/bin/tcc-boot2"

## Smoke test: -version and -c hello.c
"$TARGET/bin/tcc-boot2" -version > tcc-boot2-version.stdout 2> tcc-boot2-version.stderr
grep -q '0.9.28-darwin-bootstrap' tcc-boot2-version.stdout

cp "$SOURCES/tinycc-fixtures/boot1-link-hello.c" hello.c
"$TARGET/bin/tcc-boot2" -c hello.c -o hello.o > hello-c.stdout 2> hello-c.stderr
test "$(od -An -tx1 -N4 hello.o | tr -d ' \n')" = "7f454c46"
