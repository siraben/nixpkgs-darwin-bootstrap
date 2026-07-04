#!/bin/sh
## 44-tinycc-darwin-cc — install the Darwin-native C compiler
## wrapper.
##
## tcc-darwin-cc is the cc the whole gcc era (steps 45+) drives.  Per
## invocation it runs tcc-boot3 to compile, then replays the detour
## link: elf64-to-m1 per object/archive member, m1-split code/data
## partition, tsv-col + boot-ar archive symbol resolution, ctor-table
## C++ init-table synthesis, synth-inject cross-object label fixups,
## m1-to-hex2 --auto-data-align for a per-link Mach-O layout
## (line-rewrite patches 8 size/offset lines of the lowdata
## template), and hex2 for the final link.  This step stages the
## wrapper's file tree and substitutes the @PLACEHOLDER@ paths.
##
## The chain link-path tools (boot-ar, m1-split, tsv-col, ctor-table,
## line-rewrite, synth-inject) are compiled in steps 44b–44g by this
## wrapper itself; until each binary exists the wrapper falls back to
## the host tool it replaces (awk / the synth-inject.awk fixture).
## The fallbacks therefore run in this step's smoke test and in
## steps 44b–44g; from step 45 on, every link uses the chain tools.
##
## Runs:     tcc-self (built in step 35) to compile the wrapper's
##           libc M1; elf64-to-m1 (step 30); Apple /usr/bin cp/sed/
##           chmod/install for staging; /bin/bash executes the
##           installed wrapper (arrays are used, so the shebang is
##           bash).
## Inputs:   sources/tcc-darwin/tcc-darwin-cc.sh (wrapper source),
##           headers/ (bootstrap C headers), crt1-tcc-sysv.M1,
##           synth-inject.awk (fallback for step 44g's build),
##           sources/bootstrap-c/tinycc-sysv-libc.c and
##           tinycc-sysv-syscalls-amd64-darwin.M1,
##           sources/stage0-posix/M2libc/amd64/MACHO-amd64-lowdata.hex2.
## Outputs:  target/tcc-darwin-cc-root/ (bin/tcc-darwin-cc, include/,
##           share/ with libc M1 + crt1 + template + awk fallback)
##           and target/bin/tcc-darwin-cc.
## Verifies: smoke run — the wrapper compiles and links hello.c and
##           ./hello exits 42, covering the whole per-link pipeline.
## Trust:    the installed wrapper runs under host /bin/bash with
##           Apple /usr/bin utilities for orchestration; host awk
##           fallbacks are exercised only while steps 44b–44g build
##           their chain replacements.  The Nix recipe's codesigning
##           step is dropped (unsigned binaries run here).
set -eu

mes_source="$TARGET/mes-source"
out="$TARGET/tcc-darwin-cc-root"
rm -rf "$out"
mkdir -p "$out/bin" "$out/include/tcc-darwin-bootstrap" "$out/share"

## Copy headers
cp -R "$SOURCES/tcc-darwin/headers/." "$out/include/tcc-darwin-bootstrap/"

## Compile tinycc-sysv-libc.c → .o → .M1: the libc M1 every
## tcc-darwin-cc link pulls in (compiled once here by tcc-self).
tcc-self -c "$SOURCES/bootstrap-c/tinycc-sysv-libc.c" -o "$out/tinycc-sysv-libc.o"
elf64-to-m1 --prefix tinycc_sysv_libc_ "$out/tinycc-sysv-libc.o" "$out/share/tinycc-sysv-libc.M1"

## Copy crt1
cp "$SOURCES/tcc-darwin/crt1-tcc-sysv.M1" "$out/share/crt1-tcc-sysv.M1"

## Install the base Mach-O load-command template (lowdata).  tcc-darwin-cc
## now generates a per-link layout from this dynamically (it substitutes
## 8 size/offset fields to match each binary's actual code size — see
## m1-to-hex2 --auto-data-align), so the old fixed small/large templates are
## gone.  The wrapper finds this file via dirname(@MACHO@).
lowdata="$SOURCES/stage0-posix/M2libc/amd64/MACHO-amd64-lowdata.hex2"
cp "$lowdata" "$out/share/MACHO-amd64-lowdata.hex2"

## Install the precise cross-object synth-label injector (awk
## post-pass) — the wrapper's fallback until step 44g builds the
## chain synth-inject binary, and the byte-comparison reference in
## 44g's smoke test.
cp "$SOURCES/tcc-darwin/synth-inject.awk" "$out/share/synth-inject.awk"

## Install the wrapper script with placeholders substituted.
## Use bash because the script uses arrays.
cp "$SOURCES/tcc-darwin/tcc-darwin-cc.sh" "$out/bin/tcc-darwin-cc"
## Must be executable: the gcc-4.6 bootstrap `as` shim invokes this
## copy in tcc-darwin-cc-root/bin directly (not the one in target/bin).
chmod 755 "$out/bin/tcc-darwin-cc"
## Substitute the @PLACEHOLDER@ tool paths; drop `-u` from the
## wrapper's set line and delete the Nix-track signing hook lines.
sed -i.bak \
    -e 's|^set -euo pipefail$|set -eo pipefail|' \
    -e "s|@SHELL@|/bin/bash|g" \
    -e "s|@TCC@|$TARGET/bin/tcc-boot3|g" \
    -e "s|@AR@|$TARGET/bin/boot-ar|g" \
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
    -e "s|@TSV_COL@|$TARGET/bin/tsv-col|g" \
    -e "s|@CTOR_TABLE@|$TARGET/bin/ctor-table|g" \
    -e "s|@LINE_REWRITE@|$TARGET/bin/line-rewrite|g" \
    -e "s|@SYNTH_INJECT_BIN@|$TARGET/bin/synth-inject|g" \
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
