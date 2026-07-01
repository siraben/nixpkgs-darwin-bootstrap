#!/bin/sh
## 01-hex0 — re-assemble hex0 from its own source via the committed seed.
## Verifies self-hosting (output is byte-identical to the seed bytes).
set -eu

cp "$SEED/hex0-amd64-darwin" "$TARGET/bin/hex0"
chmod +x "$TARGET/bin/hex0"

## Self-host check: feed the seed its own .hex0 source, compare bytes.
"$TARGET/bin/hex0" "$SOURCES/hex0-amd64-darwin.hex0" "$TARGET/share/hex0-self"
cmp "$SEED/hex0-amd64-darwin" "$TARGET/share/hex0-self"

## Stash the source under share for downstream phases that need it.
cp "$SOURCES/hex0-amd64-darwin.hex0" "$TARGET/share/"
