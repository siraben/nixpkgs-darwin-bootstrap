#!/usr/bin/env bash
## Regenerate hex0/sources/cc-arch/cc_arch_AMD64_darwin_final.hex0
## from the current stage0 sources by running the prior stdenv-based
## cc-arch chain (catm + hex2 + macho-patcher + dd) and dumping the
## post-patch, pre-sign bytes as a packed-hex .hex0 source.
##
## Use this when M2libc/amd64/cc_arch-0-darwin.hex2 or
## tools/templates/MACHO-amd64-lowdata.hex2 changes upstream.
set -euo pipefail

repo="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$repo"

## Build the stdenv-based cc-arch (no signing impact on the first
## 0x2800000 bytes — codesign just appends a trailer).
out=$(nix build --no-link --print-out-paths "$repo#packages.x86_64-darwin.cc-arch")
bin="$out/bin/cc_arch-darwin"
test -f "$bin" || { echo "cc_arch-darwin not found at $bin" >&2; exit 1; }

target="hex0/sources/cc-arch/cc_arch_AMD64_darwin_final.hex0"
mkdir -p "$(dirname "$target")"

python3 - <<PY
import os, pathlib
data = pathlib.Path("$bin").read_bytes()[:0x2800000]
assert len(data) == 0x2800000, f"short binary: {len(data)} bytes"
with open("$target", "w") as out:
    out.write("## cc-arch final binary dump as hex0 source.\n")
    out.write(f"## Bytes: {len(data)} (full pre-signing form).\n")
    out.write("## Re-emit via: hex0 cc_arch_AMD64_darwin_final.hex0 cc_arch-darwin\n")
    out.write(data.hex())
    out.write("\n")
print(f"wrote $target ({len(data)} bytes)")
PY
