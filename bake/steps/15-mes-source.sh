#!/bin/sh
## 15-mes-source — prepare GNU Mes source tree for the Darwin path.
##
## Extracts mes-0.27.1.tar.gz (downloaded by scripts/fetch-sources.sh),
## drops in our Darwin-specific files (config.h, include/darwin/...,
## lib/darwin/...), patches assert-fail call sites, and stages the
## result under target/mes-source for later phases (mes-m2, libc, ...).
set -eu

tarball="$ROOT/tarballs/mes-0.27.1.tar.gz"
if [ ! -f "$tarball" ]; then
    echo "missing $tarball; run scripts/fetch-sources.sh first" >&2
    exit 1
fi

work="$TARGET/work/mes-source"
out="$TARGET/mes-source"
rm -rf "$work" "$out"
mkdir -p "$work"
cd "$work"

tar -xzf "$tarball"
mv mes-0.27.1 "$out"
chmod -R u+w "$out"

## Drop the Darwin-specific include + lib layered over the upstream tree.
cp -R "$SOURCES/mes-darwin/include/." "$out/include/"
cp -R "$SOURCES/mes-darwin/lib/."     "$out/lib/"

## Write mes config.h (replaces what the upstream configure script
## would have generated).  Content matches packages.nix's
## mesDarwinConfigH.
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

## Point arch/ at darwin/x86_64 layer.
mkdir -p "$out/include/arch"
cp "$out/include/darwin/x86_64/kernel-stat.h" "$out/include/arch/kernel-stat.h"
cp "$out/include/darwin/x86_64/signal.h"      "$out/include/arch/signal.h"
cp "$out/include/darwin/x86_64/syscall.h"     "$out/include/arch/syscall.h"

/bin/sh "$ROOT/scripts/phase13-patch-assert-fail.sh" "$out"

## Sanity checks (same as the Nix recipe).
test -f "$out/kaem.x86_64"
test -f "$out/scripts/mescc.scm.in"
test -f "$out/lib/darwin/x86_64-mes-m2/crt1.M1"
test -f "$out/include/darwin/x86_64/syscall.h"
test -f "$out/include/arch/kernel-stat.h"
test -f "$out/include/arch/signal.h"
test -f "$out/include/arch/syscall.h"
grep -q 'MES_VERSION "0.27.1"' "$out/include/mes/config.h"
grep -q 'typedef unsigned long uintptr_t' "$out/include/mes/config.h"
