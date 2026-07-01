#!/bin/sh
## 27-tinycc-mescc-link — link tcc.M1 + libc+tcc.M1 → runnable tcc.
##
## Self-hosting property established: a working C compiler binary
## exists, built only by tools from the seed-derived chain (mes-m2
## produced the .M1s; stage0 M1 + hex2 + macho-patcher assemble and
## link them into a Mach-O).  Every later tcc generation is compiled
## by a tcc descended from this binary.
##
## Runs:     M1 (built in step 12), hex2 (step 13), macho-patcher
##           (step 06); host awk — trust boundary — splits the two
##           M1 inputs into code/data; Apple /usr/bin dd/chmod/
##           install/grep for orchestration and checks.
## Inputs:   target/share/tinycc-mescc-m1/tcc.M1 (step 23),
##           target/share/libc-tcc/libc+tcc.M1 (step 26),
##           target/mes-source M1 defs/macros + darwin crt1-libc.M1,
##           sources/stage0-posix/M2libc/amd64/MACHO-amd64-lowdata.hex2
##           (Mach-O load-command template).
## Outputs:  target/bin/tcc.
## Verifies: smoke run — `tcc -version` and `tcc --version` print the
##           pinned "0.9.28-darwin-bootstrap" string with empty
##           stderr, proving the binary loads under dyld and reaches
##           main with working argument parsing and stdio.
## Trust:    host awk for the M1 code/data split; all translation and
##           layout is chain tools.
set -eu

mes_source="$TARGET/mes-source"
work="$TARGET/work/tinycc-mescc-link"
rm -rf "$work"
mkdir -p "$work"
cd "$work"

## Split each input at its :ELF_data marker so the combined link has
## exactly one code→data transition (host awk; chain m1-split exists
## from step 44c).
split_m1() {
    input="$1"
    code="$2"
    data="$3"
    awk '
      /^:ELF_data$/ { data = 1; next }
      /^:HEX2_data$/ { next }
      data != 1 { print }
    ' "$input" > "$code"
    awk '
      /^:ELF_data$/ { data = 1; next }
      /^:HEX2_data$/ { next }
      data == 1 { print }
    ' "$input" > "$data"
}

split_m1 "$TARGET/share/libc-tcc/libc+tcc.M1" libc-tcc.code.M1 libc-tcc.data.M1
split_m1 "$TARGET/share/tinycc-mescc-m1/tcc.M1" tcc.code.M1 tcc.data.M1

{
    cat libc-tcc.code.M1
    cat tcc.code.M1
    echo ':ELF_data'
    echo ':HEX2_data'
    cat libc-tcc.data.M1
    cat tcc.data.M1
} > tcc-combined.M1

## Assemble: instruction-macro defs + mescc runtime macros + Darwin
## crt1 (process entry → main) ahead of the combined program text.
M1 \
  --architecture amd64 \
  --little-endian \
  -f "$mes_source/lib/m2/x86_64/x86_64_defs.M1" \
  -f "$mes_source/lib/x86_64-mes/x86_64.M1" \
  -f "$mes_source/lib/darwin/x86_64-mes-mescc/crt1-libc.M1" \
  -f tcc-combined.M1 \
  -o tcc.hex2

hex2 \
  --architecture amd64 \
  --little-endian \
  --base-address 0x1000000 \
  -f "$SOURCES/stage0-posix/M2libc/amd64/MACHO-amd64-lowdata.hex2" \
  -f tcc.hex2 \
  -o tcc

## Darwin's loader maps __TEXT and __DATA as separate segments;
## m2-segments moves the static-data block to the __DATA file offset
## and rewrites the RIP-relative disp32s it finds by opcode scan.
macho-patcher m2-segments tcc.hex2 tcc

## Pad the file to 0x2800000 (40 MiB) so it covers the segment
## extents declared by the fixed Mach-O template's load commands.
dd if=/dev/zero of=tcc bs=1 count=1 seek=41943039 conv=notrunc 2>/dev/null || true
chmod +x tcc
install tcc "$TARGET/bin/tcc"

## Smoke test
"$TARGET/bin/tcc" -version > tcc-version.stdout 2> tcc-version.stderr
grep -q '0.9.28-darwin-bootstrap' tcc-version.stdout
test ! -s tcc-version.stderr
"$TARGET/bin/tcc" --version > tcc-long-version.stdout 2> tcc-long-version.stderr
grep -q '0.9.28-darwin-bootstrap' tcc-long-version.stdout
