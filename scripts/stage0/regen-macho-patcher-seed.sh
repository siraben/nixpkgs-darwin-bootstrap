#!/usr/bin/env bash
## Regenerate hex0/sources/macho-patcher/macho-patcher_AMD64_darwin_final.hex0
## from the current chain by dumping a byte-identical macho-patcher binary
## (M1 + hex2 + dd pad) as a packed-hex .hex0 source.  macho-patcher is
## unsigned, so the binary is exactly 0x2800000 bytes (no trailer to strip).
##
## Use this when tools/macho-patcher.M1 or M2libc/amd64/MACHO-amd64.hex2
## changes upstream.  Run against any byte-identical macho-patcher binary
## (e.g. the bin/macho-patcher from the prior runCommand build).
set -euo pipefail

repo="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$repo"

bin="${1:-}"
if [ -z "$bin" ]; then
  echo "usage: $0 <path-to-macho-patcher-binary>" >&2
  exit 1
fi
test -f "$bin" || { echo "binary not found: $bin" >&2; exit 1; }

size=$(stat -f%z "$bin" 2>/dev/null || stat -c%s "$bin")
if [ "$size" != "$((0x2800000))" ]; then
  echo "unexpected size $size (want $((0x2800000)))" >&2
  exit 1
fi

target="hex0/sources/macho-patcher/macho-patcher_AMD64_darwin_final.hex0"
mkdir -p "$(dirname "$target")"
{
  echo "## macho-patcher final binary dump as hex0 source (0x2800000 = 41943040 bytes,"
  echo "## post-hex2 + dd-pad form; macho-patcher is unsigned, no trailer to strip)."
  echo "## Re-emit via: hex0 macho-patcher_AMD64_darwin_final.hex0 macho-patcher"
  od -An -v -tx1 "$bin" | tr -d ' \n'
  echo
} > "$target"
echo "wrote $target ($size bytes -> $((size * 2)) hex chars)"
