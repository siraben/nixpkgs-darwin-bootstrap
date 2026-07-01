#!/bin/sh
## 44b-boot-ar — compile the chain's `ar` from C with tcc-darwin-cc.
##
## Apple's /usr/bin/ar refuses the chain's ELF objects ("not a mach-o file")
## and silently drops them; boot-ar writes a 4.4BSD `ar` archive storing every
## member byte-for-byte (BSD "#1/<len>" extended names) so the gcc static libs
## keep their ELF members.  Built here — after tcc-darwin-cc (44), before the
## first gcc archive (48) — so the whole gcc build uses a CHAIN-BUILT archiver,
## not host python3.  (sources/tools/boot-ar.c is verified byte-identical to the
## retired boot-ar.py across create/replace/append/list/extract/delete.)
set -eu

"$TARGET/bin/tcc-darwin-cc" "$SOURCES/tools/boot-ar.c" -o "$TARGET/bin/boot-ar"
chmod +x "$TARGET/bin/boot-ar"
test -x "$TARGET/bin/boot-ar" || { echo "44b: boot-ar not built" >&2; exit 1; }

## Smoke test: round-trip a member through create -> list so a broken libc
## surfaces here, not deep in the gcc build.
tmp="$TARGET/work/boot-ar-smoke"
rm -rf "$tmp"; mkdir -p "$tmp"
printf 'boot-ar-ok' > "$tmp/m.o"
( cd "$tmp" && "$TARGET/bin/boot-ar" cr t.a m.o && "$TARGET/bin/boot-ar" t t.a | grep -qx m.o ) \
  || { echo "44b: boot-ar smoke test failed" >&2; exit 1; }
rm -rf "$tmp"

echo "boot-ar built at $TARGET/bin/boot-ar (chain-built, no host python)"
