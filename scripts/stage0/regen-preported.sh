#!/usr/bin/env bash
# regen-preported.sh — regenerate the committed pre-ported Darwin sources
# from upstream stage0-posix.  Run this at design-time whenever
# stage0Sources is bumped or tools/macho-patcher.M1 changes.  The Nix
# build itself never invokes this — it consumes the committed outputs
# directly, keeping the build closure free of awk/perl/python.
#
# Outputs:
#   M2libc/amd64/catm_AMD64_darwin_body.hex2  — port of catm_AMD64.hex2
#   M2libc/amd64/M0_AMD64_darwin_body.hex2    — port of M0_AMD64.hex2
#   M2libc/amd64/cc_arch-0-darwin.hex2        — M0-expanded + ported cc_amd64.M1
#   tools/macho-patcher-m0.M1                 — M0-friendly form of macho-patcher.M1
#
# Each port is a deterministic set of fixed-string substitutions that
# turn Linux SysV syscalls into Darwin equivalents.  See the per-port
# .awk scripts for the exact substitutions applied.
#
# Usage: ./scripts/stage0/regen-preported.sh
set -euo pipefail

cd "$(dirname "$0")/../.."   # repo root

# Locate stage0Sources (via nix).
STAGE0=$(nix eval --raw '.#packages.x86_64-darwin.phase3-m0.stage0Sources' 2>/dev/null \
  || nix-instantiate --eval --strict -E \
       '(import ./. {}).x86_64-darwin.stage0Sources' 2>/dev/null \
  || true)
if [ -z "$STAGE0" ] || [ ! -d "$STAGE0" ]; then
  # Fallback: grep for the store path
  STAGE0=$(find /nix/store -maxdepth 2 -name "AMD64" -path "*stage0-posix*" -type d 2>/dev/null | head -1)
  STAGE0="${STAGE0%/AMD64}"
fi
if [ ! -d "$STAGE0/AMD64" ]; then
  echo "regen-preported: couldn't locate stage0-posix-source; run 'nix build .#packages.x86_64-darwin.phase3-m0' first" >&2
  exit 1
fi
echo "Using stage0Sources: $STAGE0"

# 1. catm body
awk -f scripts/stage0/port-catm-darwin.awk \
  "$STAGE0/AMD64/catm_AMD64.hex2" \
  > M2libc/amd64/catm_AMD64_darwin_body.hex2
echo "  wrote M2libc/amd64/catm_AMD64_darwin_body.hex2"

# 2. M0 body
awk -f scripts/stage0/port-m0-darwin.awk \
  "$STAGE0/AMD64/M0_AMD64.hex2" \
  > M2libc/amd64/M0_AMD64_darwin_body.hex2
echo "  wrote M2libc/amd64/M0_AMD64_darwin_body.hex2"

# 3. cc_arch-0 (M0 expand + port)
M0=$(nix eval --raw '.#packages.x86_64-darwin.phase3-m0' 2>/dev/null)/bin/M0-darwin
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
"$M0" "$STAGE0/AMD64/cc_amd64.M1" "$tmp/cc_arch-0-linux.hex2"
awk -f scripts/stage0/port-cc-arch-darwin.awk \
  "$tmp/cc_arch-0-linux.hex2" \
  > M2libc/amd64/cc_arch-0-darwin.hex2
echo "  wrote M2libc/amd64/cc_arch-0-darwin.hex2"

# 4. macho-patcher M0 form
awk -f scripts/stage0/m1-to-m0-syntax.awk \
  tools/macho-patcher.M1 \
  > tools/macho-patcher-m0.M1
echo "  wrote tools/macho-patcher-m0.M1"

echo
echo "Now: git add the four files above and commit."
