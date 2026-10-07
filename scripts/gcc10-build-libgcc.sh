#!/bin/sh
# Build a REAL core libgcc.a with the from-seed xgcc, to replace the empty stub.
# Sourced env: expects ROOT and TARGET set (or sources gcc10-env.sh itself).
#
# The from-seed gcc-10 has four known compiler bugs that the gcc target-libgcc
# build trips over; each is worked around here (and documented in STATUS.md):
#   1. The xgcc DRIVER segfaults reading ANY external `specs` file (a read_specs
#      bug) — even an empty one, or its own byte-identical `-dumpspecs`.  The
#      built-in specs are used when no file is present, so we neutralise the
#      `specs` make target to a no-op that emits no file.
#   2. cc1 segfaults at -O1/-O2 on the overflow-checked arithmetic routines
#      (e.g. _mulvdi3) — so libgcc is built at -O0.
#   3. cc1 emits malformed TLS assembly (`...@gottpof`, should be `@GOTTPOFF`)
#      that the system `as` rejects — this blocks _eprintf (a non-essential
#      assert helper that touches the `stderr` TLS), which is excluded.
#   4. Division helpers emit malformed exception-table assembly referencing
#      __gcc_personality_v0. Build these arithmetic helpers without exception
#      handling, consistent with this core-only runtime's lack of EH support.
# The EH/unwind library (libgcc_eh.a) additionally needs <pthread.h>, absent from
# the chain --sysroot, so only the arithmetic/soft-float CORE libgcc.a is built;
# the EH/libgcc_s/emutls stubs are left in place by the caller.
#
# Invoked by step 55 after cc1/xgcc are linked; also runnable standalone by a
# maintainer against an existing build tree.  Env contract: ROOT required,
# TARGET optional (gcc10-env.sh defaults it); paths come from gcc10-env.sh.
# Trust: GCC_FOR_TARGET is the chain-built xgcc (it generates all libgcc
# code), but the target-side assemble/archive tools are Apple
# /usr/bin/as, ld, ar, ranlib — trust boundary: the system assembler turns
# xgcc's assembly into Mach-O objects and the system ar archives them, so
# libgcc.a members are host-assembled from chain-generated assembly.
# Host perl neutralises the generated Makefile's specs target.
set -eu

: "${ROOT:?gcc10-build-libgcc.sh: ROOT must be set}"
. "$ROOT/scripts/gcc10-env.sh"

B="$GCC10_BUILD"
LB="$B/x86_64-apple-darwin/libgcc"
GFT="$B/gcc/xgcc -B$B/gcc/"   # clean abs path, no "/./" (HOST_SUBDIR=. injects one)

mt() {
  "$MAKE" "$@" -j1 MAKEINFO=true \
    NATIVE_SYSTEM_HEADER_DIR="$GCC10_SYS" \
    CPP="$CPP" CXXCPP="$CXXCPP" AR="$AR" RANLIB="$RANLIB" NM="$NM" \
    AR_FOR_BUILD="$AR_FOR_BUILD" RANLIB_FOR_BUILD="$RANLIB_FOR_BUILD" \
    CFLAGS="$CFLAGS" CXXFLAGS="$CXXFLAGS" \
    "GCC_FOR_TARGET=$GFT" "CC_FOR_TARGET=$GFT" \
    AS_FOR_TARGET=/usr/bin/as LD_FOR_TARGET=/usr/bin/ld \
    AR_FOR_TARGET=/usr/bin/ar RANLIB_FOR_TARGET=/usr/bin/ranlib \
    NM_FOR_TARGET=/usr/bin/nm STRIP_FOR_TARGET=/usr/bin/strip \
    LIPO_FOR_TARGET=/usr/bin/lipo \
    "CFLAGS_FOR_TARGET=-O0 -g0" "LIBGCC2_CFLAGS=-O0 -g0"
}

# --- bug 1: neutralise the `specs` make target so no external specs file is ever
# emitted (the driver crashes reading it).  Idempotent via perl (BSD sed `c\`
# one-liners are unreliable).
perl -0777 -i -pe \
  's{^\t\$\(GCC_FOR_TARGET\) -dumpspecs > tmp-specs\n\tmv tmp-specs \$\(SPECS\)\n}{\t\@true\n}m' \
  "$B/gcc/Makefile"
rm -f "$B/gcc/specs"

# Satisfy the all-gcc re-validate: gcov-tool needs nftw() (absent) and stmp-fixinc
# has a doubled header path — give both valid stamps, then freeze mtimes so make
# treats all-gcc as up to date (the stamps out-rank their frozen prerequisites).
cp "$B/gcc/gcov" "$B/gcc/gcov-tool" 2>/dev/null || true
chmod +x "$B/gcc/gcov-tool" 2>/dev/null || true
mkdir -p "$B/gcc/include-fixed"; touch "$B/gcc/stmp-fixinc"
find "$GCC10_SRC" -print0 | xargs -0 touch -t 202601010000 2>/dev/null || true
find "$B"         -print0 | xargs -0 touch -t 202701010000 2>/dev/null || true

cd "$B" || exit 2

# Configure the target libgcc subtree (creates $LB/Makefile). A configure
# failure is not an acceptable partial runtime.
mt configure-target-libgcc

# Build only the core archive, not all-target-libgcc (which also requires the
# unavailable EH runtime). Let make enumerate the complete prerequisite set;
# never package a glob of whichever objects happened to compile before an error.
# LIB2ADDEH is included in libgcc.a for static-only builds, so exclude it
# explicitly. Keep GCC's full LIBGCC2_CFLAGS: the generated libgcc.mvars already
# selects -O0, and overriding the whole variable drops required definitions.
rm -f "$LB/libgcc.a"
"$MAKE" -C "$LB" libgcc.a -j1 MAKEINFO=true \
  AR=/usr/bin/ar AR_FOR_TARGET=/usr/bin/ar RANLIB=/usr/bin/ranlib \
  LIB2FUNCS_ST=__gcc_bcmp LIB2ADDEH= \
  "LIB2_DIVMOD_EXCEPTION_FLAGS=-fno-exceptions -fno-non-call-exceptions"

test -f "$LB/libgcc.a" || {
  echo "gcc10-build-libgcc: FAILED to produce a core libgcc.a" >&2
  exit 1
}
cp "$LB/libgcc.a" "$B/gcc/libgcc.a"
echo "gcc10-build-libgcc: installed real core libgcc.a ($(/usr/bin/ar t "$B/gcc/libgcc.a" | wc -l | tr -d ' ') members)"
