#!/usr/bin/env bash
# regen-hex0-sources.sh — regenerate the committed hand-rolled hex0
# sources for hex1-darwin and hex2-darwin.  Run at design-time whenever
# stage0Sources is bumped or the Mach-O layout changes; never invoked
# from the Nix build itself.
#
# Outputs (paths under nix/):
#   hex0/sources/hex1_AMD64_darwin.hex0   (assembled by hex0 → hex1-darwin)
#   hex0/sources/hex2_AMD64_darwin.hex0   (assembled by hex0 → hex2-darwin)
#
# Approach: each file is a byte-faithful dump of the meaningful (non-
# zero-padding) portion of the corresponding Mach-O binary as produced
# by the `phase{1,2}-amd64-{hex1,hex2}.pl` flow, split into commented
# sections (Mach-O header, ported body with RIP-rel32 disps already
# baked in, EINTR retry stub for hex1).
#
# This regenerator depends on those perl helpers, kept under
# nix/scripts/stage0/legacy/ as the canonical "how those bytes were
# computed" reference.  Build-time has zero perl/awk.
set -euo pipefail

cd "$(dirname "$0")/../.."   # the nix/ tree

STAGE0=$(find /nix/store -maxdepth 2 -name AMD64 -path "*stage0-posix*" -type d 2>/dev/null | head -1)
STAGE0=${STAGE0%/AMD64}
if [ ! -d "$STAGE0/AMD64" ]; then
  echo "regen-hex0-sources: couldn't locate stage0-posix-source; run a baseline build first" >&2
  exit 1
fi

HEX0=$(nix eval --raw '.#packages.x86_64-darwin.hex0' 2>/dev/null)/bin/hex0
HEX1=$(nix eval --raw '.#packages.x86_64-darwin.hex1' 2>/dev/null)/bin/hex1-darwin
if [ ! -x "$HEX0" ] || [ ! -x "$HEX1" ]; then
  echo "regen-hex0-sources: hex0 / hex1-darwin must already be built (nix build .#hex0 .#hex1)" >&2
  exit 1
fi

if [ ! -f scripts/stage0/legacy/phase1-amd64-hex1.pl ] \
   || [ ! -f scripts/stage0/legacy/phase2-amd64-hex2.pl ]; then
  echo "regen-hex0-sources: scripts/stage0/legacy/phase{1,2}-amd64-{hex1,hex2}.pl needed as the byte-source-of-truth" >&2
  exit 1
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# --- hex1 ---
perl scripts/stage0/legacy/phase1-amd64-hex1.pl "$STAGE0" "$HEX0" "$tmp/hex1"
size=$(wc -c < "$tmp/hex1/hex1-darwin")
# Find last non-zero byte
last=$(od -An -t u1 -v "$tmp/hex1/hex1-darwin" | awk '
  { for (i = 1; i <= NF; i++) { off = (NR-1)*16 + (i-1); if ($i != 0) last = off } }
  END { print last + 1 }
')
emit_section() { # infile start length bpl label
  printf '\n## ---- %s (%d bytes from 0x%x) ----\n' "$5" "$3" "$2"
  od -An -t x1 -v -N "$3" -j "$2" "$1" | awk -v bpl="$4" '
    { for (i = 1; i <= NF; i++) {
        col = ((NR-1)*16 + (i-1)) % bpl
        if (col == 0) { if (NR > 1 || i > 1) printf "\n"; printf "  " }
        printf "%s ", toupper($i)
      }
    }
    END { printf "\n" }
  '
}

cat hex0/sources/hex1_AMD64_darwin.hex0 | head -34 > "$tmp/hex1.head"   # prologue
{
  cat "$tmp/hex1.head"
  emit_section "$tmp/hex1/hex1-darwin"    0  1024 16 "Mach-O header (0x000-0x3FF)"
  emit_section "$tmp/hex1/hex1-darwin" 1024   508 16 "Body: Darwin-ported hex1 (0x400-0x5FB)"
  emit_section "$tmp/hex1/hex1-darwin" 1532  2049 32 "Zero filler so stub lands at 0xDFD"
  emit_section "$tmp/hex1/hex1-darwin" 3581    15 16 "EINTR retry stub (0xDFD-0xE0B)"
} > hex0/sources/hex1_AMD64_darwin.hex0
echo "  wrote hex0/sources/hex1_AMD64_darwin.hex0"

# --- hex2 ---
perl scripts/stage0/legacy/phase2-amd64-hex2.pl "$STAGE0" "$HEX1" "$tmp/hex2"
cat hex0/sources/hex2_AMD64_darwin.hex0 | head -22 > "$tmp/hex2.head"   # prologue
{
  cat "$tmp/hex2.head"
  emit_section "$tmp/hex2/hex2-darwin"    0  1024 16 "Mach-O header (0x000-0x3FF)"
  emit_section "$tmp/hex2/hex2-darwin" 1024  1420 16 "Body: Darwin-ported hex2 linker (0x400-0x98B)"
} > hex0/sources/hex2_AMD64_darwin.hex0
echo "  wrote hex0/sources/hex2_AMD64_darwin.hex0"

echo
echo "Now: git diff to review, then git add + commit."
