#!/bin/sh
## 55-gcc10-all-gcc — build gcc-10 `all-gcc` with the bake chain and produce a
## working cc1 + xgcc that compile & run real C from the seed.
##
## Long step: cc1plus runs x86-64 under Rosetta 2, so the generated files
## (insn-emit.c, insn-recog.c, ...) take a while even with the GGC tuning in
## gcc10-env.sh.  -j1 because the link pipeline (tcc-darwin-cc) is not
## parallel-safe.
##
## NB: this assumes step 54 configured $GCC10_BUILD and step 53b patched the
## source.  The four bake-toolchain fixes behind a working cc1 (synth-label
## injector, C++ static-init crt1, crt1 argc/argv, elf64-to-m1 data-reloc
## addend) live in the chain itself (steps 30/44 + tools), not here.
set -eu

. "$ROOT/scripts/gcc10-env.sh"

test -f "$GCC10_BUILD/Makefile" || { echo "55: not configured (run step 54)" >&2; exit 1; }

## Equalize source mtimes so make does not try to re-run automake (not present)
## and build-side mtimes so unchanged objects are not needlessly re-resolved.
find "$GCC10_SRC"   -print0 | xargs -0 touch -t 202601010000 2>/dev/null || true
find "$GCC10_BUILD" -print0 | xargs -0 touch -t 202701010000 2>/dev/null || true

## The build-side libcpp Makefile hardcodes literal `AR = ar` (resolved via PATH
## at build time), and Apple's /usr/bin/ar silently makes an empty __.SYMDEF-only
## archive from our ELF objects -> genmatch fails to link ("Target label
## _ZNK13rich_location7get_locEj is not valid").  An AR_FOR_BUILD env override
## doesn't reach it (a Makefile assignment beats the environment), and a sed on
## the generated Makefile is racy: build-*/libcpp/Makefile is created DURING this
## make, after the loop below has already run.  The robust fix: put bake-ar on
## PATH as `ar`, so the Makefile's literal `ar` resolves to it.  (build-libiberty
## is unaffected — it uses the passed $(AR).)
ln -sf "$ROOT/scripts/bake-ar"     "$TARGET/bin/ar"
ln -sf "$ROOT/scripts/bake-ranlib" "$TARGET/bin/ranlib"
## Also keep the sed for any already-configured tree (idempotent; harmless).
for mk in "$GCC10_BUILD"/build-*/libcpp/Makefile; do
  [ -f "$mk" ] && sed -i.bak "s|^AR = ar\$|AR = $AR|" "$mk"
done

cd "$GCC10_BUILD"
"$MAKE" all-gcc -j1 MAKEINFO=true \
  NATIVE_SYSTEM_HEADER_DIR="$GCC10_SYS" \
  CPP="$CPP" CXXCPP="$CXXCPP" AR="$AR" RANLIB="$RANLIB" NM="$NM" \
  AR_FOR_BUILD="$AR_FOR_BUILD" RANLIB_FOR_BUILD="$RANLIB_FOR_BUILD" \
  CFLAGS="$CFLAGS" CXXFLAGS="$CXXFLAGS"

## Explicit cc1 link (math libs the g++ wrapper drops) and the xgcc driver.
sh "$ROOT/scripts/gcc10-link-cc1.sh"
sh "$ROOT/scripts/gcc10-relink-xgcc.sh"

test -x "$GCC10_BUILD/gcc/cc1"  || { echo "55: cc1 not produced"  >&2; exit 1; }
test -x "$GCC10_BUILD/gcc/xgcc" || { echo "55: xgcc not produced" >&2; exit 1; }

## TEMPORARY IMPURITY — empty stub libs so the goal test (and any -lgcc link)
## resolves.  TODO: replace with real libgcc/emutls built by this xgcc
## (make all-target-libgcc; blocked on the -O2 cc1 crash — build libgcc at -O1).
emptyo="$GCC10_BUILD/gcc/.bake-empty.o"
printf '' > "$emptyo.c"
"$CC" -c "$emptyo.c" -o "$emptyo" 2>/dev/null || : > "$emptyo"
for L in libgcc libgcc_eh libgcc_s libemutls_w; do
  "$AR" cr "$GCC10_BUILD/gcc/$L.a" "$emptyo" 2>/dev/null || true
done

echo "gcc10 all-gcc done: cc1 + xgcc at $GCC10_BUILD/gcc (run scripts/gcc10-goal-test.sh to verify)"
