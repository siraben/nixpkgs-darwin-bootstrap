#!/bin/sh
## 31-tinycc-elf-to-macho — convert tcc-compiled ELF .o → Mach-O via
## elf64-to-m1 + M1 + hex2 + macho-patcher.  Mirrors
## tinycc/elf-to-macho.nix.
##
## Self-hosting property established: the full ELF-object detour
## works end-to-end for an executable — code compiled by the chain
## tcc runs as a Darwin Mach-O process.  This is the link recipe
## steps 35/38/40/42 and the tcc-darwin-cc wrapper reuse.
##
## Runs:     tcc (built in step 27), elf64-to-m1 (step 30), M1 (step
##           12), hex2 (step 13), macho-patcher (step 06); host awk —
##           trust boundary — splits the converted M1 into code/data;
##           Apple /usr/bin cp/od/tr/dd/chmod for orchestration.
## Inputs:   sources/tinycc-fixtures/elf-to-macho-hello.c and
##           elf-to-macho-crt1-tcc-sysv.M1 (hand-written entry stub
##           for tcc's SysV-ABI code),
##           sources/stage0-posix/M2libc/amd64/MACHO-amd64-lowdata.hex2.
## Outputs:  none installed; scratch hello binary under
##           target/work/tinycc-elf-to-macho.
## Verifies: ./hello exits 42 — compile, ELF→M1 conversion, assembly,
##           link, segment patch and process startup all correct.
## Trust:    host awk for the M1 code/data split.
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

## --prefix namespaces the object's LOCAL symbols (hello_...) so
## labels from different objects cannot collide in a combined link.
elf64-to-m1 --prefix hello_ hello.o hello-object.M1

## Combine: crt1 entry stub first, then the object's code section, a
## single :ELF_data/:HEX2_data boundary, then its data section.
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

## Move static data to the __DATA file offset and rewrite the
## RIP-relative disp32s found by opcode scan (lowdata template maps
## __TEXT and __DATA separately).
macho-patcher m2-segments hello.hex2 hello

## Pad the file to 0x2800000 (40 MiB), the extent the fixed template
## declares.
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
