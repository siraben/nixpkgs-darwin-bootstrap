#!/bin/sh
## 55-gcc10-all-gcc — build gcc-10 `all-gcc` with the from-seed chain and produce a
## working cc1 + xgcc that compile & run real C from the seed.
##
## Long step: cc1plus runs x86-64 under Rosetta 2, so the generated files
## (insn-emit.c, insn-recog.c, ...) take a while even with the GGC tuning in
## gcc10-env.sh.  -j1 because the link pipeline (tcc-darwin-cc) is not
## parallel-safe.
##
## NB: this assumes step 54 configured $GCC10_BUILD and step 53b patched the
## source.  The four from-seed-toolchain fixes behind a working cc1 (synth-label
## injector, C++ static-init crt1, crt1 argc/argv, elf64-to-m1 data-reloc
## addend) live in the chain itself (steps 30/44 + tools), not here.
##
## Runs:    chain make (step 45); chain gcc-4.6 g++ (steps 52/52b) as
##          CXX — it compiles all of gcc-10's C++ sources; chain
##          tcc-darwin-cc (step 44) as CC and as the final linker inside
##          the g++ wrapper; chain boot-ar/boot-ranlib for archives;
##          scripts/gcc10-link-cc1.sh and scripts/gcc10-relink-xgcc.sh
##          for the final links; scripts/gcc10-build-libgcc.sh for the
##          core libgcc (that script uses the freshly built xgcc plus
##          Apple /usr/bin/as, ld, ar for the target side — see its
##          header);
##          host /usr/bin/cc + /usr/bin/ar for the libgcc_eh/libgcc_s/
##          libemutls_w stub archives — trust boundary (a one-symbol
##          Mach-O stub; the system ld used by the goal test rejects
##          other archive formats);
##          Apple find/xargs/touch/ln/sed for orchestration.
## Inputs:  $GCC10_BUILD configured by step 54; $TARGET/gcc10-source
##          (steps 53 + 53b); env from scripts/gcc10-env.sh.
## Outputs: $GCC10_BUILD/gcc/{cc1,xgcc}; $GCC10_BUILD/gcc/libgcc.a (real
##          core archive by default; stub only with BOOT_ALLOW_STUB_LIBGCC=1)
##          and stub libgcc_eh.a/
##          libgcc_s.a/libemutls_w.a; `ar`/`ranlib` symlinks in
##          $TARGET/bin pointing at boot-ar/boot-ranlib.
## Verifies: cc1 and xgcc exist and are executable.  The end-to-end
##          proof (xgcc compiles and runs real C) is
##          scripts/gcc10-goal-test.sh, kept separate because it links
##          the final executable with the system ld — the chain has no
##          native Mach-O executable linker for gcc output.
## Trust:   gcc-10 code generation is chain-only; host cc/ar appear only
##          for the runtime stub archives called out above.
set -eu

. "$ROOT/scripts/gcc10-env.sh"

test -f "$GCC10_BUILD/Makefile" || { echo "55: not configured (run step 54)" >&2; exit 1; }

## Equalize source mtimes so make does not try to re-run automake (not present)
## and build-side mtimes so unchanged objects are not needlessly re-resolved.
find "$GCC10_SRC"   -print0 | xargs -0 touch -t 202601010000 2>/dev/null || true
find "$GCC10_BUILD" -print0 | xargs -0 touch -t 202701010000 2>/dev/null || true

## Force the chain `ar` everywhere the gcc-10 build archives a static lib.
##
## gcc's libcpp / intl / libdecnumber Makefile.in templates hardcode a LITERAL
## `AR = ar` (a bare tool name, NOT @AR@), so configure / the exported AR /
## config.site cannot change it — the archive rule always runs a bare `ar`,
## resolved via PATH at build time.  On the first full `make all-gcc` the
## build-side (build-x86_64-apple-darwin) recursion can lose the PATH race and
## resolve `ar` to Apple's /usr/bin/ar, which refuses our ELF members
## ("not a mach-o file") and writes an empty 96-byte __.SYMDEF archive.
## build/genmatch — the one generator linking the build-side libcpp.a — then
## fails to link ("Target label _ZNK13rich_location7get_locEj is not valid").
## It's a heisenbug: it only bites when the bare `ar` loses the race, so warm /
## incremental rebuilds (Makefiles already generated) usually dodge it.
##
## Robust, PATH-independent fix: rewrite the literal `AR = ar` in the SOURCE
## templates to the absolute chain ar before configure runs, so every Makefile
## configure generates (host AND build-side) gets an unambiguous archiver.
## Keep `ar`/`ranlib` on PATH and rewrite any already-generated Makefiles too,
## as belt-and-suspenders for warm trees.
ln -sf "$TARGET/bin/boot-ar"        "$TARGET/bin/ar"
ln -sf "$ROOT/scripts/boot-ranlib" "$TARGET/bin/ranlib"
for mkin in "$GCC10_SRC"/libcpp/Makefile.in \
            "$GCC10_SRC"/intl/Makefile.in \
            "$GCC10_SRC"/libdecnumber/Makefile.in; do
  [ -f "$mkin" ] && sed -i.bak "s|^AR = ar\$|AR = $TARGET/bin/boot-ar|" "$mkin" \
    && rm -f "$mkin.bak"
done
for mk in $(grep -rlE '^AR = ar$' "$GCC10_BUILD" --include=Makefile 2>/dev/null); do
  sed -i.bak "s|^AR = ar\$|AR = $TARGET/bin/boot-ar|" "$mk" && rm -f "$mk.bak"
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
## In a clean tree $GCC10_BUILD/gcc does not exist until make first descends
## into it (step 54 configures only the top level), so create it for the
## stubs; the gcc sub-configure works fine in a pre-existing empty dir.
mkdir -p "$GCC10_BUILD/gcc"
for g in gcov gcov-dump gcov-tool; do
  printf '#!/bin/sh\nexit 0\n' > "$GCC10_BUILD/gcc/$g"
  chmod +x "$GCC10_BUILD/gcc/$g"
  touch -t 202801010000 "$GCC10_BUILD/gcc/$g"
done

## `all-gcc` also runs fixincludes (target `stmp-fixinc`), which patches the
## *system* headers for portability bugs — irrelevant to the cc1/xgcc goal.  Our
## --sysroot + absolute NATIVE_SYSTEM_HEADER_DIR makes its sysroot-header path
## double up (".../tcc-darwin-bootstrap/tmp/.../tcc-darwin-bootstrap"), so the
## recipe reports "directory that should contain system headers does not exist"
## and -j1 make stops before cc1.  (Again the warm tree only passed because a
## stmp-fixinc stamp + include-fixed/ dir were already present.)  Pre-create the
## stamp + dir with a far-future mtime so make treats fixincludes as done.
mkdir -p "$GCC10_BUILD/gcc/include-fixed"
: > "$GCC10_BUILD/gcc/stmp-fixinc"
touch -t 202801010000 "$GCC10_BUILD/gcc/include-fixed" "$GCC10_BUILD/gcc/stmp-fixinc"

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
## requires Mach-O archives — a boot-ar ELF archive or a memberless macOS-ar
## archive would be rejected).
stubo="$GCC10_BUILD/gcc/.boot-stub.o"
printf 'static int _boot_stub;\n' > "$stubo.c"
/usr/bin/cc -arch x86_64 -c "$stubo.c" -o "$stubo"
for L in libgcc_eh libgcc_s libemutls_w; do
  rm -f "$GCC10_BUILD/gcc/$L.a"
  /usr/bin/ar cr "$GCC10_BUILD/gcc/$L.a" "$stubo"
done
## Real core libgcc.a.  Fall back to a stub only when explicitly requested for
## debugging; a normal successful build must preserve the real-libgcc proof.
if ! sh "$ROOT/scripts/gcc10-build-libgcc.sh"; then
  if [ "${BOOT_ALLOW_STUB_LIBGCC:-0}" != 1 ]; then
    echo "55: real libgcc build failed; refusing stub fallback (set BOOT_ALLOW_STUB_LIBGCC=1 for debugging)" >&2
    exit 1
  fi
  echo "55: real libgcc build failed; BOOT_ALLOW_STUB_LIBGCC=1, installing stub libgcc.a" >&2
  rm -f "$GCC10_BUILD/gcc/libgcc.a"
  /usr/bin/ar cr "$GCC10_BUILD/gcc/libgcc.a" "$stubo"
fi
member_count=$(/usr/bin/ar -t "$GCC10_BUILD/gcc/libgcc.a" | wc -l | tr -d ' ')
if [ "${BOOT_ALLOW_STUB_LIBGCC:-0}" != 1 ] && [ "$member_count" -lt 100 ]; then
  echo "55: libgcc.a has only $member_count members; expected the real core archive" >&2
  exit 1
fi

echo "gcc10 all-gcc done: cc1 + xgcc at $GCC10_BUILD/gcc (run scripts/gcc10-goal-test.sh to verify)"
