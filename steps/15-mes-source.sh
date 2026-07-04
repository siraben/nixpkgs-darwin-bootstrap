#!/bin/sh
## 15-mes-source — stage the GNU Mes source tree for the Darwin path.
##
## Mes provides the Scheme interpreter (mes-m2, step 18) and the mescc
## C compiler (steps 20-21) that carry the chain from M2-Planet-class
## C to tinycc.  This step extracts the pinned mes-0.27.1 tarball,
## layers the committed Darwin-specific include/ and lib/ files over
## it, writes include/mes/config.h (the file upstream configure would
## generate; content matches packages.nix's mesDarwinConfigH), points
## include/arch/ at the darwin/x86_64 headers, and rewrites
## lib/mes/__assert_fail.c via a helper script.
##
## Runs:     Apple tar, mv, chmod, cp, mkdir, cat, test, grep;
##           /bin/sh runs scripts/phase13-patch-assert-fail.sh, which
##           runs host /usr/bin/perl.
## Inputs:   tarballs/mes-0.27.1.tar.gz (fetched against a pinned
##           SHA-256 by scripts/fetch-sources.sh),
##           sources/mes-darwin/{include,lib},
##           scripts/phase13-patch-assert-fail.sh.
## Outputs:  target/mes-source (full prepared tree; consumed by steps
##           17, 18, 20, 21 and later).
## Verifies: presence checks for the files later steps consume
##           (kaem.run, mescc.scm.in, the Darwin crt1.M1 and arch
##           headers) and content greps on the generated config.h.
## Trust:    host /usr/bin/perl edits C source here (splits `&&`
##           conditions in __assert_fail.c into nested ifs for
##           M2-Planet-class compilers) — a host-tool source
##           transformation, part of the documented trust boundary in
##           build.sh.  The tarball is upstream release text pinned
##           by hash.
set -eu
. "$ROOT/scripts/tarball-sha256s.sh"

tarball="$ROOT/tarballs/mes-0.27.1.tar.gz"
boot_verify_tarball "$tarball" || exit 1

work="$TARGET/work/mes-source"
out="$TARGET/mes-source"
rm -rf "$work" "$out"
mkdir -p "$work"
cd "$work"

tar -xzf "$tarball"
mv mes-0.27.1 "$out"
## Make the whole tree writable: this step writes config.h and
## include/arch below, and the perl helper edits __assert_fail.c.
chmod -R u+w "$out"

## Drop the Darwin-specific include + lib layered over the upstream tree.
cp -R "$SOURCES/mes-darwin/include/." "$out/include/"
cp -R "$SOURCES/mes-darwin/lib/."     "$out/lib/"

## Write mes config.h (replaces what the upstream configure script
## would have generated).  Content matches packages.nix's
## mesDarwinConfigH.  The #ifndef __M2__ guard skips the typedefs
## when M2-Planet compiles this header (M2-Planet defines __M2__).
mkdir -p "$out/include/mes"
cat > "$out/include/mes/config.h" <<'CFG'
#ifndef _MES_CONFIG_H
#undef SYSTEM_LIBC
#define MES_VERSION "0.27.1"
#ifndef __M2__
typedef unsigned long uintptr_t;
typedef unsigned long size_t;
typedef long ssize_t;
typedef long intptr_t;
typedef long ptrdiff_t;
#define __MES_SIZE_T
#define __MES_SSIZE_T
#define __MES_INTPTR_T
#define __MES_UINTPTR_T
#define __MES_PTRDIFF_T
#endif
#endif
CFG

## Point arch/ at darwin/x86_64 layer.  Mes sources include
## <arch/...>; upstream configure would select the kernel/cpu dir.
mkdir -p "$out/include/arch"
cp "$out/include/darwin/x86_64/kernel-stat.h" "$out/include/arch/kernel-stat.h"
cp "$out/include/darwin/x86_64/signal.h"      "$out/include/arch/signal.h"
cp "$out/include/darwin/x86_64/syscall.h"     "$out/include/arch/syscall.h"

## Host perl rewrite of lib/mes/__assert_fail.c (see Trust above).
/bin/sh "$ROOT/scripts/phase13-patch-assert-fail.sh" "$out"

## Sanity checks (same as the Nix recipe): the exact files steps 17,
## 18, and 20 consume must exist, and config.h must carry the version
## and typedefs written above.
test -f "$out/kaem.x86_64"
test -f "$out/scripts/mescc.scm.in"
test -f "$out/lib/darwin/x86_64-mes-m2/crt1.M1"
test -f "$out/include/darwin/x86_64/syscall.h"
test -f "$out/include/arch/kernel-stat.h"
test -f "$out/include/arch/signal.h"
test -f "$out/include/arch/syscall.h"
grep -q 'MES_VERSION "0.27.1"' "$out/include/mes/config.h"
grep -q 'typedef unsigned long uintptr_t' "$out/include/mes/config.h"
