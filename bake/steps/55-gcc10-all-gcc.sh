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
## Symlink `ar` to the self-contained chain-built bake-ar BINARY (not the
## scripts/bake-ar shim): gcc-10's build-side libcpp sub-make invokes `ar`
## without TARGET in its environment, and the shim's TARGET fallback
## (`$dir/../target`) is wrong for a scratch TARGET, so it would silently
## produce an EMPTY libcpp.a and genmatch would fail to link
## (`Target label _ZNK13rich_location7get_locEj is not valid`).  The binary
## needs no env.  bake-ranlib is a pure no-op shim, so it is fine as-is.
ln -sf "$TARGET/bin/bake-ar"        "$TARGET/bin/ar"
ln -sf "$ROOT/scripts/bake-ranlib" "$TARGET/bin/ranlib"
## Also keep the sed for any already-configured tree (idempotent; harmless).
for mk in "$GCC10_BUILD"/build-*/libcpp/Makefile; do
  [ -f "$mk" ] && sed -i.bak "s|^AR = ar\$|AR = $AR|" "$mk"
done

## `all-gcc` also links the coverage programs gcov / gcov-dump / gcov-tool,
## which are NOT bootstrap-goal binaries (the goal is cc1 + xgcc).  gcov-tool
## pulls in libgcov-util.o, whose `ftw_close`/directory walk references libc's
## nftw(3) — a symbol absent from the chain --sysroot libc — so the from-seed
## link dies with `Target label nftw is not valid` and -j1 make stops before
## cc1.  (The warm tree only got past this because a gcov-tool stub had been
## hand-placed there; a clean from-seed build hits it every time.)  Pre-place
## executable stubs with a far-future mtime so make sees them up to date versus
## their freshly-compiled .o and skips the link entirely.  These tools are never
## executed on the cc1/xgcc goal path.
for g in gcov gcov-dump gcov-tool; do
  printf '#!/bin/sh\nexit 0\n' > "$GCC10_BUILD/gcc/$g"
  chmod +x "$GCC10_BUILD/gcc/$g"
  touch -t 202801010000 "$GCC10_BUILD/gcc/$g"
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

## libgcc.  The CORE libgcc.a (arithmetic / soft-float routines) is now a REAL
## archive built by the from-seed xgcc itself (scripts/gcc10-build-libgcc.sh,
## which works around three from-seed-compiler bugs — see STATUS.md).  The
## EH/unwind library (libgcc_eh) needs <pthread.h>, absent from the chain
## --sysroot, so libgcc_eh / libgcc_s / libemutls_w stay symbol-less x86_64
## Mach-O stubs (xgcc references them for -lgcc_eh/-lemutls_w but the C goal test
## needs none of their symbols; the final exe link uses the SYSTEM ld, which
## requires Mach-O archives — a bake-ar ELF archive or a memberless macOS-ar
## archive would be rejected).
stubo="$GCC10_BUILD/gcc/.bake-stub.o"
printf 'static int _bake_stub;\n' > "$stubo.c"
/usr/bin/cc -arch x86_64 -c "$stubo.c" -o "$stubo"
for L in libgcc_eh libgcc_s libemutls_w; do
  rm -f "$GCC10_BUILD/gcc/$L.a"
  /usr/bin/ar cr "$GCC10_BUILD/gcc/$L.a" "$stubo"
done
## Real core libgcc.a; fall back to a stub only if the build cannot produce one.
if ! sh "$ROOT/scripts/gcc10-build-libgcc.sh"; then
  echo "55: real libgcc build failed; falling back to a stub libgcc.a" >&2
  rm -f "$GCC10_BUILD/gcc/libgcc.a"
  /usr/bin/ar cr "$GCC10_BUILD/gcc/libgcc.a" "$stubo"
fi

echo "gcc10 all-gcc done: cc1 + xgcc at $GCC10_BUILD/gcc (run scripts/gcc10-goal-test.sh to verify)"
