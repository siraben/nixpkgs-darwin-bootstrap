#!/bin/sh
## 16-m2-planet — build the full M2-Planet.
##
## This M2-Planet is compiled against the full M2libc (string.c,
## stat, stdio, ...) and linked by M1 + hex2, and is installed under
## the name `M2-Planet`, which mes's kaem.run (step 17) invokes.
## Step 08's M2-darwin — the cc_arch-compiled, M0-linked bootstrap
## binary — serves as the compiler here.  Mirrors m2-planet.nix.
##
## Runs:     M2-darwin (step 08), M1 (step 12), hex2 (step 13),
##           macho-patcher (step 06); Apple dd, chmod, install, grep.
## Inputs:   sources/stage0-posix/M2-Planet/*.c + cc.h, M2libc
##           headers and libc .c files (listed below),
##           M2libc/amd64/{amd64_defs.M1,libc-full-Darwin.M1,
##           MACHO-amd64-lowdata.hex2}.
## Outputs:  target/bin/M2-Planet.
## Verifies: grep for untranslated M1 tokens (see step 08); smoke
##           test — --help prints the M2-Planet usage text.
## Trust:    translation and layout by chain-built tools.  Apple dd
##           appends content-free zero padding; /bin/sh orchestrates.
set -eu

work="$TARGET/work/m2-planet"
mkdir -p "$work"
cd "$work"

src="$SOURCES/stage0-posix"

## Full M2libc build (see step 11 for the ordering rationale).
M2-darwin \
  --architecture amd64 \
  -f "$src/M2libc/sys/types.h" \
  -f "$src/M2libc/stddef.h" \
  -f "$src/M2libc/sys/utsname.h" \
  -f "$src/M2libc/amd64/Darwin/unistd.c" \
  -f "$src/M2libc/amd64/Darwin/fcntl.c" \
  -f "$src/M2libc/fcntl.c" \
  -f "$src/M2libc/amd64/Darwin/sys/stat.c" \
  -f "$src/M2libc/ctype.c" \
  -f "$src/M2libc/stdlib.c" \
  -f "$src/M2libc/string.c" \
  -f "$src/M2libc/stdarg.h" \
  -f "$src/M2libc/stdio.h" \
  -f "$src/M2libc/stdio.c" \
  -f "$src/M2libc/bootstrappable.c" \
  -f "$src/M2-Planet/cc.h" \
  -f "$src/M2-Planet/cc_globals.c" \
  -f "$src/M2-Planet/cc_reader.c" \
  -f "$src/M2-Planet/cc_strings.c" \
  -f "$src/M2-Planet/cc_types.c" \
  -f "$src/M2-Planet/cc_emit.c" \
  -f "$src/M2-Planet/cc_core.c" \
  -f "$src/M2-Planet/cc_macro.c" \
  -f "$src/M2-Planet/cc.c" \
  -o M2-Planet.M1

M1 \
  --architecture amd64 \
  --little-endian \
  -f "$src/M2libc/amd64/amd64_defs.M1" \
  -f "$src/M2libc/amd64/libc-full-Darwin.M1" \
  -f M2-Planet.M1 \
  -o M2-Planet.hex2

## Fail fast if M1 left any M1 mnemonic or DEFINE unexpanded (see
## step 08).
if grep -q 'sub_rdi\|lea_r9\|mov_rdi,rbp\|DWORD\|DEFINE' M2-Planet.hex2; then
  echo "M2-Planet hex2 contains untranslated M1 tokens" >&2
  exit 1
fi

## --base-address 0x600000 = __TEXT vmaddr of the lowdata template
## (see step 12).
hex2 \
  --architecture amd64 \
  --little-endian \
  --base-address 0x600000 \
  -f "$src/M2libc/amd64/MACHO-amd64-lowdata.hex2" \
  -f M2-Planet.hex2 \
  -o M2-Planet

macho-patcher m2-segments M2-Planet.hex2 M2-Planet

## Pad to the 0x2800000 __LINKEDIT file offset (see step 05).
dd if=/dev/zero of=M2-Planet bs=1 count=1 seek=41943039 conv=notrunc 2>/dev/null || true
chmod +x M2-Planet
install M2-Planet "$TARGET/bin/M2-Planet"

## Smoke test
"$TARGET/bin/M2-Planet" --help > help.stdout 2>&1
grep -q 'Usage: M2-Planet' help.stdout
