#!/bin/sh
## 20-mescc-trivial — instantiate mescc.scm and compile a trivial C
## file with it, validating the mes-m2 + mescc + nyacc pipeline
## end-to-end before the libc build (step 21) relies on it.
##
## mescc is mes's C compiler written in Scheme.  This step fills in
## the @prefix@/@VERSION@/@mes_cpu@/@mes_kernel@ placeholders in
## upstream scripts/mescc.scm.in (the substitution upstream configure
## would perform; mirrors mes/m2.nix's sed pipeline), then runs
## mes-m2 on the resulting mescc.scm to compile a one-line C fixture
## to M1 assembly.
##
## Runs:     Apple sed performs the placeholder substitution (host
##           text edit, configure-style); mes-m2 (step 18) runs
##           mescc.scm with nyacc (step 19) on the load path; Apple
##           cp, chmod, install, test, grep.
## Inputs:   target/mes-source/scripts/mescc.scm.in (step 15),
##           target/nyacc/share/nyacc-1.09.1 (step 19),
##           sources/mes-fixtures/m2-trivial.c (committed fixture:
##           `int main () { return 0; }`).
## Outputs:  target/share/mescc-trivial/{mescc.scm,trivial.M1,
##           mescc-trivial.stdout,mescc-trivial.stderr}; step 21 and
##           later phases reuse the staged mescc.scm.
## Verifies: trivial.M1 is non-empty and contains a `main` label —
##           the interpreter parsed C via nyacc and emitted M1.
## Trust:    host sed rewrites placeholder strings in Scheme source;
##           C-to-M1 translation is done by chain-built mes-m2 +
##           mescc.scm.  /bin/sh orchestrates.
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

## MES_STACK/MES_ARENA/MES_MAX_ARENA size the interpreter's stack and
## heap for the mescc workload.  M1/HEX2 point mescc.scm at the chain
## assembler and linker.  -S stops after the compile stage, so this
## run produces M1 assembly text only.
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
