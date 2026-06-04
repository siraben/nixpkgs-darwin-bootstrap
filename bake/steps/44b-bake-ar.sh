#!/bin/sh
## 44b-bake-ar — compile the chain's `ar` from C with tcc-darwin-cc.
##
## Apple's /usr/bin/ar refuses the chain's ELF objects ("not a mach-o file")
## and silently drops them; bake-ar writes a 4.4BSD `ar` archive storing every
## member byte-for-byte (BSD "#1/<len>" extended names) so the gcc static libs
## keep their ELF members.  Built here — after tcc-darwin-cc (44), before the
## first gcc archive (48) — so the whole gcc build uses a CHAIN-BUILT archiver,
## not host python3.  (sources/tools/bake-ar.c is verified byte-identical to the
## retired bake-ar.py across create/replace/append/list/extract/delete.)
set -eu

"$TARGET/bin/tcc-darwin-cc" "$SOURCES/tools/bake-ar.c" -o "$TARGET/bin/bake-ar"
chmod +x "$TARGET/bin/bake-ar"
test -x "$TARGET/bin/bake-ar" || { echo "44b: bake-ar not built" >&2; exit 1; }

## Smoke test: round-trip a member through create -> list so a broken libc
## surfaces here, not deep in the gcc build.
tmp="$TARGET/work/bake-ar-smoke"
rm -rf "$tmp"; mkdir -p "$tmp"
printf 'bake-ar-ok' > "$tmp/m.o"
( cd "$tmp" && "$TARGET/bin/bake-ar" cr t.a m.o && "$TARGET/bin/bake-ar" t t.a | grep -qx m.o ) \
  || { echo "44b: bake-ar smoke test failed" >&2; exit 1; }
rm -rf "$tmp"

echo "bake-ar built at $TARGET/bin/bake-ar (chain-built, no host python)"
