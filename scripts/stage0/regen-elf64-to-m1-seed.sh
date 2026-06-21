#!/usr/bin/env bash
## Regenerate hex0/sources/elf64-to-m1/elf64-to-m1_AMD64_darwin_final.hex0
## from the current stage0 chain by building the old stdenv-based
## elf64-to-m1 (M1 + hex2 + dd pad) and dumping its bytes as a packed-hex
## .hex0 source.  elf64-to-m1 is unsigned, so the binary is exactly
## 0x2800000 bytes and there is no codesign trailer to strip.
##
## Use this when tools/elf64-to-m1.M1 or M2libc/amd64/MACHO-amd64.hex2
## changes upstream.  Run BEFORE the seed-as-builder elf64-to-m1.nix is in
## place (check out the prior runCommand version), or point it at any
## byte-identical elf64-to-m1 binary.
set -euo pipefail

repo="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$repo"

bin="${1:-}"
if [ -z "$bin" ]; then
  echo "usage: $0 <path-to-elf64-to-m1-binary>" >&2
  echo "  (e.g. the bin/elf64-to-m1 from a runCommand-built elf64-to-m1)" >&2
  exit 1
fi
test -f "$bin" || { echo "binary not found: $bin" >&2; exit 1; }

size=$(stat -f%z "$bin" 2>/dev/null || stat -c%s "$bin")
if [ "$size" != "$((0x2800000))" ]; then
  echo "unexpected size $size (want $((0x2800000)))" >&2
  exit 1
fi

target="hex0/sources/elf64-to-m1/elf64-to-m1_AMD64_darwin_final.hex0"
mkdir -p "$(dirname "$target")"
{
  echo "## elf64-to-m1 final binary dump as hex0 source (0x2800000 = 41943040 bytes,"
  echo "## post-hex2 + dd-pad form; elf64-to-m1 is unsigned, so no trailer to strip)."
  echo "## Re-emit via: hex0 elf64-to-m1_AMD64_darwin_final.hex0 elf64-to-m1"
  od -An -v -tx1 "$bin" | tr -d ' \n'
  echo
} > "$target"
echo "wrote $target ($size bytes -> $((size * 2)) hex chars)"
