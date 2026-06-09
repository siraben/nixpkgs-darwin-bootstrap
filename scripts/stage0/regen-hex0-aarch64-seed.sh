#!/usr/bin/env bash
# regen-hex0-aarch64-seed.sh — regenerate the committed aarch64-darwin
# hex0 seed (hex0/seed/hex0-aarch64-darwin) and its source
# (hex0/hex0-aarch64-darwin.hex0) from hex0/hex0-aarch64-darwin.S.
#
# Design-time authoring tool; the Nix build never runs it.  Host clang,
# otool, and codesign participate here the same way the legacy perl
# helpers did for the amd64 seed: they document how the committed bytes
# were produced.  Trust comes from the committed .S/.hex0 sources and
# the self-hosting check (hex0(source) == seed, byte-for-byte).
#
# The seed layout: MACHO-aarch64.hex2 template with __TEXT tightened to
# 16 KB, body at the LC_MAIN entry offset 0x2c8, zero padding to the
# __LINKEDIT file offset 0x4000, then the ad-hoc code-signature blob.
# The signature hashes only the pages before it, so embedding it in the
# .hex0 source keeps the self-hosted output validly signed.
set -euo pipefail

cd "$(dirname "$0")/../.."   # repo root
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

clang -arch arm64 -c hex0/hex0-aarch64-darwin.S -o "$tmp/hex0.o"
python3 scripts/stage0/aarch64-seed-mk.py "$tmp/hex0.o" "$tmp/seed-unsigned"
cp "$tmp/seed-unsigned" "$tmp/seed"
codesign -s - -i hex0-aarch64-darwin -f "$tmp/seed"
chmod 755 "$tmp/seed"
python3 scripts/stage0/aarch64-seed-emit-hex0.py "$tmp/seed" "$tmp/hex0.o" \
  "$tmp/hex0-aarch64-darwin.hex0"

# self-host gate: the seed must reproduce itself from the emitted source
"$tmp/seed" "$tmp/hex0-aarch64-darwin.hex0" "$tmp/seed-self"
cmp "$tmp/seed" "$tmp/seed-self"

install -m755 "$tmp/seed" hex0/seed/hex0-aarch64-darwin
install -m644 "$tmp/hex0-aarch64-darwin.hex0" hex0/hex0-aarch64-darwin.hex0
echo "regenerated hex0/seed/hex0-aarch64-darwin ($(wc -c < "$tmp/seed" | tr -d ' ') bytes)"
