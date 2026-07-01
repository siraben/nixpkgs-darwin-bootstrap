#!/bin/sh
## 01-hex0 — stage the trust-root seed binary and prove it self-hosts.
##
## hex0 translates hexadecimal byte pairs (with '#'/';' comments) into
## raw bytes: hex0 INPUT OUTPUT.  It is the only committed binary in
## the chain; every later binary derives from committed text through
## it.  This step installs the seed as target/bin/hex0 for all later
## steps, then feeds the seed its own fully-commented .hex0 source.
##
## Runs:     the seed itself (seed/hex0-amd64-darwin); Apple /bin/sh,
##           cp, chmod, cmp for orchestration and the byte comparison.
## Inputs:   seed/hex0-amd64-darwin, sources/hex0-amd64-darwin.hex0.
## Outputs:  target/bin/hex0, target/share/hex0-self,
##           target/share/hex0-amd64-darwin.hex0.
## Verifies: cmp of the seed against its re-assembled output — byte
##           identity proves the committed source describes exactly
##           the committed seed bytes (self-hosting).
## Trust:    the 4 KB seed Mach-O is the trust root.  All other tools
##           here are Apple-signed utilities doing orchestration; no
##           host tool performs translation or binary layout.
set -eu

cp "$SEED/hex0-amd64-darwin" "$TARGET/bin/hex0"
chmod +x "$TARGET/bin/hex0"

## Self-host check: feed the seed its own .hex0 source, compare bytes.
"$TARGET/bin/hex0" "$SOURCES/hex0-amd64-darwin.hex0" "$TARGET/share/hex0-self"
cmp "$SEED/hex0-amd64-darwin" "$TARGET/share/hex0-self"

## Stash the source under share for downstream phases that need it.
cp "$SOURCES/hex0-amd64-darwin.hex0" "$TARGET/share/"
