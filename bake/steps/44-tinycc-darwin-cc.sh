#!/bin/sh
## 44-tinycc-darwin-cc — the final Darwin-native tcc wrapper.
##
## Generates MACHO-amd64-largedata.hex2 (segment-resized variant of
## the lowdata template), substitutes paths into tcc-darwin-cc.sh,
## and verifies it compiles+links a hello binary that runs.
##
## Note: tcc-darwin-cc.sh requires bash (uses arrays).  We use
## /bin/bash for the shebang.  The signing step from the Nix recipe
## is skipped (Apple-signed binaries aren't necessary for runtime).
set -eu

mes_source="$TARGET/mes-source"
out="$TARGET/tcc-darwin-cc-root"
rm -rf "$out"
mkdir -p "$out/bin" "$out/include/tcc-darwin-bootstrap" "$out/share"

## Copy headers
cp -R "$SOURCES/tcc-darwin/headers/." "$out/include/tcc-darwin-bootstrap/"

## Compile tinycc-sysv-libc.c → .o → .M1
tcc-self -c "$SOURCES/bootstrap-c/tinycc-sysv-libc.c" -o "$out/tinycc-sysv-libc.o"
elf64-to-m1 --prefix tinycc_sysv_libc_ "$out/tinycc-sysv-libc.o" "$out/share/tinycc-sysv-libc.M1"

## Copy crt1
cp "$SOURCES/tcc-darwin/crt1-tcc-sysv.M1" "$out/share/crt1-tcc-sysv.M1"

## Generate two Mach-O segment-layout templates from lowdata via 7 awk
## byte substitutions each.  tcc-darwin-cc tries the SMALL layout first
## (fast: minimal text padding) and falls back to LARGE only when a
## binary's text overruns it (e.g. gcc-4.6 cc1plus).  Keeping the small
## layout as default preserves fast configure conftests.
lowdata="$SOURCES/stage0-posix/M2libc/amd64/MACHO-amd64-lowdata.hex2"
## SMALL: __TEXT vmsize 0x1100000 (17.8MB), __DATA @0x1700000, linkedit @0x3100000
awk '
NR==10 { print "00 00 60 00 00 00 00 00 00 00 10 01 00 00 00 00"; next }
NR==11 { print "00 00 00 00 00 00 00 00 00 00 10 01 00 00 00 00"; next }
NR==15 { print "00 04 60 00 00 00 00 00 00 fc 0f 01 00 00 00 00"; next }
NR==19 { print "00 00 00 00 00 00 00 00 00 00 70 01 00 00 00 00"; next }
NR==20 { print "00 00 00 02 00 00 00 00 00 00 10 01 00 00 00 00"; next }
NR==24 { print "00 00 70 03 00 00 00 00 00 10 00 00 00 00 00 00"; next }
NR==25 { print "00 00 10 03 00 00 00 00 00 00 00 00 00 00 00 00"; next }
{ print }
' "$lowdata" > "$out/share/MACHO-amd64-smalldata.hex2"
## LARGE: __TEXT vmsize 0x2800000 (42MB), __DATA @0x2E00000, linkedit @0x4800000
awk '
NR==10 { print "00 00 60 00 00 00 00 00 00 00 80 02 00 00 00 00"; next }
NR==11 { print "00 00 00 00 00 00 00 00 00 00 80 02 00 00 00 00"; next }
NR==15 { print "00 04 60 00 00 00 00 00 00 fc 7f 02 00 00 00 00"; next }
NR==19 { print "00 00 00 00 00 00 00 00 00 00 e0 02 00 00 00 00"; next }
NR==20 { print "00 00 00 02 00 00 00 00 00 00 80 02 00 00 00 00"; next }
NR==24 { print "00 00 e0 04 00 00 00 00 00 10 00 00 00 00 00 00"; next }
NR==25 { print "00 00 80 04 00 00 00 00 00 00 00 00 00 00 00 00"; next }
{ print }
' "$lowdata" > "$out/share/MACHO-amd64-largedata.hex2"

## Install the wrapper script with placeholders substituted.
## Use bash because the script uses arrays.
cp "$SOURCES/tcc-darwin/tcc-darwin-cc.sh" "$out/bin/tcc-darwin-cc"
## Must be executable: the gcc-4.6 bootstrap `as` shim invokes this
## copy in tcc-darwin-cc-root/bin directly (not the one in target/bin).
chmod 755 "$out/bin/tcc-darwin-cc"
sed -i.bak \
    -e 's|^set -euo pipefail$|set -eo pipefail|' \
    -e "s|@SHELL@|/bin/bash|g" \
    -e "s|@TCC@|$TARGET/bin/tcc-boot3|g" \
    -e "s|@AR@|/usr/bin/ar|g" \
    -e "s|@INCLUDE@|$out/include/tcc-darwin-bootstrap|g" \
    -e "s|@ELF_TO_M1@|$TARGET/bin/elf64-to-m1|g" \
    -e "s|@M1_TO_HEX2@|$TARGET/bin/m1-to-hex2|g" \
    -e "s|@HEX2@|$TARGET/bin/hex2|g" \
    -e "s|@MACHO@|$out/share/MACHO-amd64-largedata.hex2|g" \
    -e "s|@CRT1@|$out/share/crt1-tcc-sysv.M1|g" \
    -e "s|@SYSCALLS@|$SOURCES/bootstrap-c/tinycc-sysv-syscalls-amd64-darwin.M1|g" \
    -e "s|@LIBC_M1@|$out/share/tinycc-sysv-libc.M1|g" \
    -e '/^source @SIGNING@$/d' \
    -e '/^sign "\$out"$/d' \
    "$out/bin/tcc-darwin-cc"
rm -f "$out/bin/tcc-darwin-cc.bak"

## Install to TARGET/bin so PATH picks it up
install "$out/bin/tcc-darwin-cc" "$TARGET/bin/tcc-darwin-cc"

## Smoke test: compile a hello world that returns 42
work="$TARGET/work/darwin-cc"
mkdir -p "$work"
cd "$work"
cat > hello.c <<C
int main(void) { return 42; }
C
"$TARGET/bin/tcc-darwin-cc" hello.c -o hello 2>&1 | tail -5
set +e
./hello
status="$?"
set -e
if [ "$status" -ne 42 ]; then
    echo "hello returned $status, expected 42" >&2
    exit 1
fi
echo "tcc-darwin-cc hello → exit 42 ✓"

