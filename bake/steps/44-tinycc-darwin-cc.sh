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

## Install the base Mach-O load-command template (lowdata).  tcc-darwin-cc
## now generates a per-link layout from this dynamically (it substitutes
## the 7 segment-size fields to match each binary's actual code size — see
## m1-to-hex2 --auto-data-align), so the old fixed small/large templates are
## gone.  The wrapper finds this file via dirname(@MACHO@).
lowdata="$SOURCES/stage0-posix/M2libc/amd64/MACHO-amd64-lowdata.hex2"
cp "$lowdata" "$out/share/MACHO-amd64-lowdata.hex2"

## Install the precise cross-object synth-label injector (awk post-pass).
cp "$SOURCES/tcc-darwin/synth-inject.awk" "$out/share/synth-inject.awk"

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
    -e "s|@AR@|$TARGET/bin/bake-ar|g" \
    -e "s|@INCLUDE@|$out/include/tcc-darwin-bootstrap|g" \
    -e "s|@ELF_TO_M1@|$TARGET/bin/elf64-to-m1|g" \
    -e "s|@M1_TO_HEX2@|$TARGET/bin/m1-to-hex2|g" \
    -e "s|@HEX2@|$TARGET/bin/hex2|g" \
    -e "s|@MACHO@|$out/share/MACHO-amd64-lowdata.hex2|g" \
    -e "s|@CRT1@|$out/share/crt1-tcc-sysv.M1|g" \
    -e "s|@SYSCALLS@|$SOURCES/bootstrap-c/tinycc-sysv-syscalls-amd64-darwin.M1|g" \
    -e "s|@LIBC_M1@|$out/share/tinycc-sysv-libc.M1|g" \
    -e "s|@SYNTH_INJECT@|$out/share/synth-inject.awk|g" \
    -e "s|@M1_SPLIT@|$TARGET/bin/m1-split|g" \
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

