#!/bin/sh
## 18-mes-m2 — link mes.M1 into a runnable mes-m2 Mach-O binary.
##
## Mirrors mes/m2-link.nix.  Uses M1 (phase 9) to compose with the
## M1 defs/lib for x86_64-mes-m2, then hex2 (phase 10) for the
## Mach-O link with the lowdata MACHO template, then macho-patcher
## for segment fixups, then pad.
set -eu

mes_source="$TARGET/mes-source"
mes_m1="$TARGET/share/mes-m2-probe/mes.M1"
test -f "$mes_m1" || { echo "missing $mes_m1" >&2; exit 1; }

work="$TARGET/work/mes-m2"
rm -rf "$work"
mkdir -p "$work"
cd "$work"

M1 \
  --architecture amd64 \
  --little-endian \
  -f "$mes_source/lib/m2/x86_64/x86_64_defs.M1" \
  -f "$mes_source/lib/x86_64-mes/x86_64.M1" \
  -f "$mes_source/lib/darwin/x86_64-mes-m2/crt1.M1" \
  -f "$mes_m1" \
  -o mes.hex2

hex2 \
  --architecture amd64 \
  --little-endian \
  --base-address 0x1000000 \
  -f "$SOURCES/stage0-posix/M2libc/amd64/MACHO-amd64-lowdata.hex2" \
  -f mes.hex2 \
  -o mes-m2

macho-patcher m2-segments mes.hex2 mes-m2

dd if=/dev/zero of=mes-m2 bs=1 count=1 seek=41943039 conv=notrunc 2>/dev/null || true
chmod +x mes-m2
install mes-m2 "$TARGET/bin/mes-m2"

## Smoke test: mes-m2 prints 'Hello,M2-mes!' when given a (display) form.
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
test ! -s mes-m2-run.stderr
