#!/bin/sh
## 32-tinycc-self-m1 — convert the self-compiled tcc.o (step 29's
## output) into an M1 file via elf64-to-m1.
##
## Self-hosting property established: the self-compiled compiler
## object survives the ELF→M1 detour at full scale — the whole of
## tcc.o converts and the result is syntactically valid M1 (M1
## assembles it to hex2).  Step 35 links the converted file into the
## tcc-self binary.
##
## Runs:     elf64-to-m1 (built in step 30), M1 (step 12); Apple
##           /usr/bin grep/install/cp for checks and orchestration.
## Inputs:   target/share/tinycc-self-object/tcc.o (step 29).
## Outputs:  target/share/tinycc-self-m1/{tcc-from-elf.M1,
##           tcc-from-elf.hex2}.
## Verifies: tcc-from-elf.M1 defines :main and :tcc_new, references
##           %memcpy and %vsnprintf (libc symbols left for the
##           step-35 link to satisfy), and carries the :ELF_data
##           section marker; M1 assembles it to a non-empty hex2.
## Trust:    none beyond prior chain outputs.
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
