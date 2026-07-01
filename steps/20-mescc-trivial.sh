#!/bin/sh
## 20-mescc-trivial — write target-specific mescc.scm and use mes-m2
## to compile a trivial.c → trivial.M1.  This validates the
## mes-m2 + mescc + nyacc pipeline end-to-end.
set -eu

mes_source="$TARGET/mes-source"
nyacc_dir="$TARGET/nyacc/share/nyacc-1.09.1"
work="$TARGET/work/mescc-trivial"
rm -rf "$work"
mkdir -p "$work"
cd "$work"

## Install mescc.scm with @prefix@/@VERSION@/etc. substituted (mirrors
## mes/m2.nix's sed pipeline).
sed \
    -e "s|@prefix@|$mes_source|g" \
    -e "s|@VERSION@|0.27.1|g" \
    -e "s|@mes_cpu@|x86_64|g" \
    -e "s|@mes_kernel@|darwin|g" \
    "$mes_source/scripts/mescc.scm.in" > mescc.scm
chmod 444 mescc.scm

## Compile m2-trivial.c → trivial.M1 via mes-m2 driving mescc.scm.
cp "$SOURCES/mes-fixtures/m2-trivial.c" trivial.c

mesLoadPath="$mes_source/module:$mes_source/mes/module:$nyacc_dir/module"

MES_PREFIX="$mes_source" \
    GUILE_LOAD_PATH="$mesLoadPath" \
    MES_STACK=6000000 \
    MES_ARENA=60000000 \
    MES_MAX_ARENA=60000000 \
    srcdest="$mes_source/" \
    includedir="$mes_source/include" \
    libdir="$mes_source/lib" \
    M1="$TARGET/bin/M1" \
    HEX2="$TARGET/bin/hex2" \
    mes-m2 --no-auto-compile -e main mescc.scm -- \
      -S -I "$mes_source/include" -D HAVE_CONFIG_H=1 \
      trivial.c -o trivial.M1 \
    > mescc-trivial.stdout 2> mescc-trivial.stderr

test -s trivial.M1
grep -q main trivial.M1

install -d "$TARGET/share/mescc-trivial"
cp trivial.M1 mescc.scm mescc-trivial.stdout mescc-trivial.stderr \
   "$TARGET/share/mescc-trivial/"
