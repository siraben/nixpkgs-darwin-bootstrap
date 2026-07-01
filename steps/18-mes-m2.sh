#!/bin/sh
## 18-mes-m2 — link mes.M1 into the runnable mes-m2 Scheme
## interpreter.  Mirrors mes/m2-link.nix.
##
## mes-m2 is the GNU Mes interpreter compiled by M2-Planet (step 17).
## It executes mescc.scm (steps 20-21), the Scheme C compiler that
## carries the chain toward tinycc.  M1 (step 12) assembles mes.M1
## together with mes's own x86_64 defs and the Darwin mes-m2 crt1;
## hex2 (step 13) links with the lowdata MACHO template;
## macho-patcher applies the m2-segments fixup (see step 06); dd
## pads.
##
## Runs:     M1 (step 12), hex2 (step 13), macho-patcher (step 06);
##           Apple dd, chmod, install, grep, cat, test; the fresh
##           mes-m2 for its own smoke test.
## Inputs:   target/share/mes-m2-probe/mes.M1 (step 17);
##           target/mes-source lib/m2/x86_64/x86_64_defs.M1,
##           lib/x86_64-mes/x86_64.M1,
##           lib/darwin/x86_64-mes-m2/crt1.M1 (step 15);
##           sources/stage0-posix/M2libc/amd64/MACHO-amd64-lowdata.hex2.
## Outputs:  target/bin/mes-m2.
## Verifies: smoke test — evaluate a (display ...) form with
##           MES_PREFIX/GUILE_LOAD_PATH pointing at the mes tree;
##           checks the interpreter boots, loads its Scheme modules,
##           prints the expected text, and writes nothing to stderr.
## Trust:    translation and layout by chain-built tools.  Apple dd
##           appends content-free zero padding; /bin/sh orchestrates.
set -eu

mes_source="$TARGET/mes-source"
mes_m1="$TARGET/share/mes-m2-probe/mes.M1"
test -f "$mes_m1" || { echo "missing $mes_m1" >&2; exit 1; }

work="$TARGET/work/mes-m2"
rm -rf "$work"
mkdir -p "$work"
cd "$work"

## mes ships its own M1 defs (x86_64_defs.M1 + x86_64.M1) and the
## Darwin mes-m2 crt1; mes.M1 references these definitions.
M1 \
  --architecture amd64 \
  --little-endian \
  -f "$mes_source/lib/m2/x86_64/x86_64_defs.M1" \
  -f "$mes_source/lib/x86_64-mes/x86_64.M1" \
  -f "$mes_source/lib/darwin/x86_64-mes-m2/crt1.M1" \
  -f "$mes_m1" \
  -o mes.hex2

## --base-address 0x1000000 for the mes image (matches the Nix
## recipe); the mescc-tools binaries use 0x600000.
hex2 \
  --architecture amd64 \
  --little-endian \
  --base-address 0x1000000 \
  -f "$SOURCES/stage0-posix/M2libc/amd64/MACHO-amd64-lowdata.hex2" \
  -f mes.hex2 \
  -o mes-m2

macho-patcher m2-segments mes.hex2 mes-m2

## Pad to the 0x2800000 __LINKEDIT file offset (see step 05).
dd if=/dev/zero of=mes-m2 bs=1 count=1 seek=41943039 conv=notrunc 2>/dev/null || true
chmod +x mes-m2
install mes-m2 "$TARGET/bin/mes-m2"

## Smoke test: mes-m2 prints 'Hello,M2-mes!' when given a (display) form.
## MES_PREFIX/GUILE_LOAD_PATH let the interpreter locate its Scheme
## modules in the staged mes tree.
set +e
MES_PREFIX="$mes_source" \
  GUILE_LOAD_PATH="$mes_source/module:$mes_source/mes/module" \
  "$TARGET/bin/mes-m2" -c "(display 'Hello,M2-mes!) (newline)" \
  > mes-m2-run.stdout 2> mes-m2-run.stderr
status=$?
set -e

if [ "$status" -ne 0 ]; then
    echo "mes-m2 returned $status; stderr:" >&2
    cat mes-m2-run.stderr >&2
    exit 1
fi
grep -q 'Hello,M2-mes!' mes-m2-run.stdout
## Empty stderr rules out warnings/errors the exit status would hide.
test ! -s mes-m2-run.stderr
