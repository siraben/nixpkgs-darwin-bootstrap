#!/bin/sh
## 44b-boot-ar — compile the chain's `ar` from C with tcc-darwin-cc.
##
## Apple's /usr/bin/ar rejects the chain's ELF objects ("not a mach-o
## file") and silently drops them; boot-ar writes a 4.4BSD `ar`
## archive storing every member byte-for-byte (BSD "#1/<len>"
## extended names) so the gcc static libs keep their ELF members.
## The wrapper's @AR@ hook points here, so archive extraction in the
## tcc-darwin-cc link path and every gcc archive (first one in step
## 48) use the chain-built archiver.  boot-ar replaces host python3
## (boot-ar.py) in the link path; its output is verified
## byte-identical to boot-ar.py across create/replace/append/list/
## extract/delete.
##
## Runs:     tcc-darwin-cc (installed in step 44, driving tcc-boot3
##           and the detour link path with host-awk fallbacks, since
##           the 44c–44g chain tools are not built yet); Apple
##           /usr/bin chmod/grep/printf for orchestration and checks.
## Inputs:   sources/tools/boot-ar.c.
## Outputs:  target/bin/boot-ar.
## Verifies: smoke test — create an archive from one member and list
##           it back, so a broken chain libc surfaces here instead of
##           deep in the gcc build.
## Trust:    host awk runs inside this step's tcc-darwin-cc link
##           (fallback path); the produced boot-ar is chain code.
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
