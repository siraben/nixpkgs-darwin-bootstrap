#!/bin/sh
## 27-tinycc-mescc-link — link tcc.M1 + libc+tcc.M1 → runnable tcc.
##
## This is the first working tcc binary in the chain — built ONLY by
## tools from the seed-derived chain (mes-m2 produced the .M1s,
## stage0 M1+hex2+macho-patcher link them into a Mach-O).
set -eu

mes_source="$TARGET/mes-source"
work="$TARGET/work/tinycc-mescc-link"
rm -rf "$work"
mkdir -p "$work"
cd "$work"

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

macho-patcher m2-segments tcc.hex2 tcc

dd if=/dev/zero of=tcc bs=1 count=1 seek=41943039 conv=notrunc 2>/dev/null || true
chmod +x tcc
install tcc "$TARGET/bin/tcc"

## Smoke test
"$TARGET/bin/tcc" -version > tcc-version.stdout 2> tcc-version.stderr
grep -q '0.9.28-darwin-bootstrap' tcc-version.stdout
test ! -s tcc-version.stderr
"$TARGET/bin/tcc" --version > tcc-long-version.stdout 2> tcc-long-version.stderr
grep -q '0.9.28-darwin-bootstrap' tcc-long-version.stdout
