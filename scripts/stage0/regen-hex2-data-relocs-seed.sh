#!/usr/bin/env bash
## Regenerate hex0/sources/hex2-data-relocs/hex2-data-relocs_AMD64_darwin_final.hex0 from the
## current stage0 chain by dumping a byte-identical hex2-data-relocs binary (M2-Planet
## bootstrap/hex2-data-relocs.c -> M1 -> hex2 -> macho-patcher -> dd pad 0x2800000 -> ad-hoc codesign)
## as a packed-hex .hex0 source.  hex2-data-relocs is signed, so the binary is larger
## than 0x2800000 (base + codesign trailer); the full signed file is captured.
##
## Use this when bootstrap/hex2-data-relocs.c or M2libc/amd64/MACHO-amd64-lowdata.hex2 changes.  Run
## against any byte-identical hex2-data-relocs binary, e.g.:
##   nix build .#packages.x86_64-darwin.hex2-data-relocs -o /tmp/hex2-data-relocs-result
##   scripts/stage0/regen-hex2-data-relocs-seed.sh /tmp/hex2-data-relocs-result/bin/hex2-data-relocs
set -euo pipefail

repo="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$repo"

bin="${1:-}"
if [ -z "$bin" ]; then
  echo "usage: $0 <path-to-hex2-data-relocs-binary>" >&2
  exit 1
fi
test -f "$bin" || { echo "binary not found: $bin" >&2; exit 1; }

size=$(stat -f%z "$bin" 2>/dev/null || stat -c%s "$bin")
if [ "$size" -lt "$((0x2800000))" ]; then
  echo "unexpected size $size (want >= $((0x2800000)) for the dd-padded + signed binary)" >&2
  exit 1
fi

target="hex0/sources/hex2-data-relocs/hex2-data-relocs_AMD64_darwin_final.hex0"
mkdir -p "$(dirname "$target")"
{
  echo "## hex2-data-relocs final signed binary dump as hex0 source ($size bytes; post-hex2 +"
  echo "## dd-pad 0x2800000 + ad-hoc codesign, so size exceeds 0x2800000)."
  echo "## Re-emit via: hex0 hex2-data-relocs_AMD64_darwin_final.hex0 hex2-data-relocs"
  od -An -v -tx1 "$bin" | tr -d ' \n'
  echo
} > "$target"
echo "wrote $target ($size bytes -> $((size * 2)) hex chars)"
