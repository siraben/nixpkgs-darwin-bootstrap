#!/usr/bin/env bash
## Regenerate hex0/sources/m1-to-hex2/m1-to-hex2_AMD64_darwin_final.hex0 from the
## current stage0 chain by dumping a byte-identical m1-to-hex2 binary (M2-Planet
## bootstrap/m1-to-hex2.c -> M1 -> hex2 -> macho-patcher -> dd pad 0x2800000 -> ad-hoc codesign)
## as a packed-hex .hex0 source.  m1-to-hex2 is signed, so the binary is larger
## than 0x2800000 (base + codesign trailer); the full signed file is captured.
##
## Use this when bootstrap/m1-to-hex2.c or M2libc/amd64/MACHO-amd64-lowdata.hex2 changes.  Run
## against any byte-identical m1-to-hex2 binary, e.g.:
##   nix build .#packages.x86_64-darwin.m1-to-hex2 -o /tmp/m1-to-hex2-result
##   scripts/stage0/regen-m1-to-hex2-seed.sh /tmp/m1-to-hex2-result/bin/m1-to-hex2
set -euo pipefail

repo="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$repo"

bin="${1:-}"
if [ -z "$bin" ]; then
  echo "usage: $0 <path-to-m1-to-hex2-binary>" >&2
  exit 1
fi
test -f "$bin" || { echo "binary not found: $bin" >&2; exit 1; }

size=$(stat -f%z "$bin" 2>/dev/null || stat -c%s "$bin")
if [ "$size" -lt "$((0x2800000))" ]; then
  echo "unexpected size $size (want >= $((0x2800000)) for the dd-padded + signed binary)" >&2
  exit 1
fi

target="hex0/sources/m1-to-hex2/m1-to-hex2_AMD64_darwin_final.hex0"
mkdir -p "$(dirname "$target")"
{
  echo "## m1-to-hex2 final signed binary dump as hex0 source ($size bytes; post-hex2 +"
  echo "## dd-pad 0x2800000 + ad-hoc codesign, so size exceeds 0x2800000)."
  echo "## Re-emit via: hex0 m1-to-hex2_AMD64_darwin_final.hex0 m1-to-hex2"
  od -An -v -tx1 "$bin" | tr -d ' \n'
  echo
} > "$target"
echo "wrote $target ($size bytes -> $((size * 2)) hex chars)"
