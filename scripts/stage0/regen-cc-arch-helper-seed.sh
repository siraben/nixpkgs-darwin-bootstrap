#!/usr/bin/env bash
## Regenerate hex0/sources/cc-arch-helper/cc-arch-helper_AMD64_darwin_final.hex0 from the
## current stage0 chain by dumping a byte-identical cc-arch-helper binary (M2-Planet
## bootstrap/phase4-amd64-cc-arch.c -> M1 -> hex2 -> macho-patcher -> dd pad 0x2800000 -> ad-hoc codesign)
## as a packed-hex .hex0 source.  cc-arch-helper is signed, so the binary is larger
## than 0x2800000 (base + codesign trailer); the full signed file is captured.
##
## Use this when bootstrap/phase4-amd64-cc-arch.c or M2libc/amd64/MACHO-amd64-lowdata.hex2 changes.  Run
## against any byte-identical cc-arch-helper binary, e.g.:
##   nix build .#packages.x86_64-darwin.cc-arch-helper -o /tmp/cc-arch-helper-result
##   scripts/stage0/regen-cc-arch-helper-seed.sh /tmp/cc-arch-helper-result/bin/phase4-cc-arch-helper
set -euo pipefail

repo="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$repo"

bin="${1:-}"
if [ -z "$bin" ]; then
  echo "usage: $0 <path-to-phase4-cc-arch-helper-binary>" >&2
  exit 1
fi
test -f "$bin" || { echo "binary not found: $bin" >&2; exit 1; }

size=$(stat -f%z "$bin" 2>/dev/null || stat -c%s "$bin")
if [ "$size" -lt "$((0x2800000))" ]; then
  echo "unexpected size $size (want >= $((0x2800000)) for the dd-padded + signed binary)" >&2
  exit 1
fi

target="hex0/sources/cc-arch-helper/cc-arch-helper_AMD64_darwin_final.hex0"
mkdir -p "$(dirname "$target")"
{
  echo "## cc-arch-helper final signed binary dump as hex0 source ($size bytes; post-hex2 +"
  echo "## dd-pad 0x2800000 + ad-hoc codesign, so size exceeds 0x2800000)."
  echo "## Re-emit via: hex0 cc-arch-helper_AMD64_darwin_final.hex0 phase4-cc-arch-helper"
  od -An -v -tx1 "$bin" | tr -d ' \n'
  echo
} > "$target"
echo "wrote $target ($size bytes -> $((size * 2)) hex chars)"
