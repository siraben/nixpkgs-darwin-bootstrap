#!/bin/sh
## 44e-ctor-table — compile the C++ global-constructor table emitter from C.
##
## gcc (configured x86_64-apple-darwin) registers each TU's global-ctor entry
## via a .mod_init_func pointer the as-filter/tcc chain drops, so tcc-darwin-cc
## rebuilds the init table by scanning the code M1s for `<prefix>_GLOBAL__sub_I`
## labels.  That was a host grep|sed|awk|while pipeline — semantically-
## significant link-path machinery.  sources/tools/ctor-table.c is the chain-
## built replacement (verified byte-identical, incl. cross-file dedup-in-order).
## The wrapper prefers $TARGET/bin/ctor-table, host pipeline fallback only while
## bootstrapping it.  Built after 44d, before the first gcc archive (48).
set -eu

"$TARGET/bin/tcc-darwin-cc" "$SOURCES/tools/ctor-table.c" -o "$TARGET/bin/ctor-table"
chmod +x "$TARGET/bin/ctor-table"
test -x "$TARGET/bin/ctor-table" || { echo "44e: ctor-table not built" >&2; exit 1; }

## Smoke test: dedup-in-order across files, ignore non-ctor lines.
tmp="$TARGET/work/ctor-table-smoke"
rm -rf "$tmp"; mkdir -p "$tmp"
printf ':_GLOBAL__sub_I_a\n:x\n:_GLOBAL__sub_I_a\n' > "$tmp/1.M1"
printf ':p_GLOBAL__sub_I_b junk\n' > "$tmp/2.M1"
exp="$(printf '&_GLOBAL__sub_I_a\n!0x00 !0x00 !0x00 !0x00\n&p_GLOBAL__sub_I_b\n!0x00 !0x00 !0x00 !0x00')"
[ "$("$TARGET/bin/ctor-table" "$tmp/1.M1" "$tmp/2.M1" "$tmp/missing.M1")" = "$exp" ] \
  || { echo "44e: ctor-table smoke test failed" >&2; exit 1; }
rm -rf "$tmp"

echo "ctor-table built at $TARGET/bin/ctor-table (chain-built; ctor-table awk retired)"
