#!/bin/sh
## 53b-gcc10-patches — apply the in-tree gcc-10 source patches required to build
## cc1/xgcc with the from-seed toolchain.  Run after 53-gcc10-source.
##
## These are NOT compiler-correctness fixes for gcc itself; they work around two
## bootstrap-environment constraints:
##   (a) our from-seed gcc-4.6 cc1plus miscompiles the synthetic __FUNCTION__/
##       __func__ VAR_DECL (make_fname_decl) -> crash / spurious redeclaration in
##       some TUs.  Force the literal "?"/"" (diagnostic strings only; no codegen
##       effect).  [gcc/system.h, gcc/ipa-icf-gimple.h]
##   (b) our hex2 link materialises .bss as explicit zero bytes and does not
##       honour large alignment attributes, so gcc/config/host-darwin.c's 1 GB
##       PCH buffer must shrink to 1 MB and its page-align assert must degrade to
##       a graceful PCH-disable (PCH is never used in the bootstrap).
##
## Idempotent: re-running is a no-op once applied.
##
## Runs:    host python3 — trust boundary (in-place text edits of three
##          gcc source files; every replacement is anchored on exact
##          committed strings and aborts if the anchor is absent, so the
##          edits are auditable from this file alone).
## Inputs:  $TARGET/gcc10-source/gcc (step 53).
## Outputs: the same tree, edited in place (gcc/system.h,
##          gcc/ipa-icf-gimple.h, gcc/config/host-darwin.c).
## Verifies: each patch() call exits nonzero unless the expected text is
##          found or the replacement is already present.
set -eu

src="$TARGET/gcc10-source/gcc"

python3 - "$src" <<'PY'
import sys, os
src = sys.argv[1]

def patch(path, olds_news, label):
    p = os.path.join(src, path)
    with open(p) as f:
        s = f.read()
    changed = False
    for old, new in olds_news:
        if new in s and old not in s:
            continue                      # already applied
        if old not in s:
            raise SystemExit("53b: %s: expected text not found in %s:\n%r"
                             % (label, path, old[:80]))
        s = s.replace(old, new, 1)
        changed = True
    if changed:
        with open(p, "w") as f:
            f.write(s)
        print("53b: patched", path)
    else:
        print("53b: already patched", path)

# (a) system.h — force __FUNCTION__/__func__ to literal "?".
# Pristine gcc-10.4.0 only defines __FUNCTION__="?" when (GCC_VERSION < 2007);
# our from-seed gcc-4.6 cc1plus reports GCC_VERSION=4006, so the guard is false
# and __FUNCTION__ stays the (miscompiled) builtin.  Force it unconditionally.
patch("system.h", [(
    '/* Various error reporting routines want to use __FUNCTION__.  */\n'
    '#if (GCC_VERSION < 2007)\n'
    '#ifndef __FUNCTION__\n'
    '#define __FUNCTION__ "?"\n'
    '#endif /* ! __FUNCTION__ */\n'
    '#endif\n',
    '/* Various error reporting routines want to use __FUNCTION__.  */\n'
    '#if 1 /* boot: from-seed cc1plus miscompiles the synthetic __FUNCTION__ decl */\n'
    '#undef __FUNCTION__\n'
    '#define __FUNCTION__ "?"\n'
    '#define __func__ "?"\n'
    '#endif\n',
)], "system.h __FUNCTION__")

# (a) ipa-icf-gimple.h — drop __func__ from the return_false_with_msg macro.
patch("ipa-icf-gimple.h", [(
    'return_false_with_message_1 (message, __FILE__, __func__, __LINE__)',
    'return_false_with_message_1 (message, __FILE__, "", __LINE__)',
)], "ipa-icf-gimple.h __func__")

# (b) host-darwin.c — 1 GB PCH buffer -> 1 MB, and graceful PCH-disable instead
#     of the page-align gcc_assert (hex2 doesn't honour aligned(16384)).
patch("config/host-darwin.c", [
    ('static char pch_address_space[65536*16384] __attribute__((aligned (16384)));',
     'static char pch_address_space[1048576] __attribute__((aligned (16384)));'),
    ('  gcc_assert ((size_t)pch_address_space % pagesize == 0\n'
     '\t      && sizeof (pch_address_space) % pagesize == 0);\n',
     '  /* boot: hex2 does not honour aligned(16384); PCH is never used in the\n'
     '     from-seed bootstrap, so disable it gracefully if unaligned.  */\n'
     '  if ((size_t) pch_address_space % pagesize != 0\n'
     '      || sizeof (pch_address_space) % pagesize != 0)\n'
     '    return 0;\n'),
], "host-darwin.c PCH")
PY

echo "53b: gcc-10 source patches applied"
