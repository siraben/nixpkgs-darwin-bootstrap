#!/bin/sh
## 32-tinycc-self-m1 — convert the self-compiled tcc.o (phase 29's
## output) into a M1 file via elf64-to-m1.  Validates that the
## self-built tcc has all the symbols it needs.
set -eu

work="$TARGET/work/tinycc-self-m1"
rm -rf "$work"
mkdir -p "$work"
cd "$work"

elf64-to-m1 --prefix tcc_self_ \
    "$TARGET/share/tinycc-self-object/tcc.o" \
    tcc-from-elf.M1

grep -q '^:main$' tcc-from-elf.M1
grep -q '^:tcc_new$' tcc-from-elf.M1
grep -q '^%memcpy$' tcc-from-elf.M1
grep -q '^%vsnprintf$' tcc-from-elf.M1
grep -q '^:ELF_data$' tcc-from-elf.M1

M1 --architecture amd64 --little-endian \
    -f tcc-from-elf.M1 \
    -o tcc-from-elf.hex2
test -s tcc-from-elf.hex2

install -d "$TARGET/share/tinycc-self-m1"
cp tcc-from-elf.M1 tcc-from-elf.hex2 "$TARGET/share/tinycc-self-m1/"
