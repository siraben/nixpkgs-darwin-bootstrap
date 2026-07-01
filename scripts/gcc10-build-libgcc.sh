#!/bin/sh
# Build a REAL core libgcc.a with the from-seed xgcc, to replace the empty stub.
# Sourced env: expects ROOT and TARGET set (or sources gcc10-env.sh itself).
#
# The from-seed gcc-10 has three known compiler bugs that the gcc target-libgcc
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
# Host perl performs two Makefile text edits (specs target, _eprintf).
set -u

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

# Configure the target libgcc subtree (creates $LB/Makefile).
mt configure-target-libgcc || true

# --- bug 3: drop the TLS-using _eprintf from the func list so the malformed-TLS
# `as` error does not abort the build.
if [ -f "$LB/Makefile" ]; then
  perl -i -pe 's/^LIB2FUNCS_ST = _eprintf __gcc_bcmp$/LIB2FUNCS_ST = __gcc_bcmp/' "$LB/Makefile"
fi

# Build as much of libgcc as compiles; the EH/unwind objects fail on missing
# <pthread.h> (documented gap) — tolerate that, we only want the core.
mt all-target-libgcc || true

# Archive the CORE libgcc.a from every object that built (the EH/unwind objects
# did not, so they are simply absent).  The members are real Mach-O objects, so
# the archive is consumable by the system ld used for the final exe link.
if ls "$LB"/*.o >/dev/null 2>&1; then
  ( cd "$LB" && rm -f libgcc.a && /usr/bin/ar crs libgcc.a ./*.o )
fi

if [ -f "$LB/libgcc.a" ]; then
  cp "$LB/libgcc.a" "$B/gcc/libgcc.a"
  echo "gcc10-build-libgcc: installed real core libgcc.a ($(/usr/bin/ar t "$B/gcc/libgcc.a" | wc -l | tr -d ' ') members)"
  exit 0
fi
echo "gcc10-build-libgcc: FAILED to produce a core libgcc.a" >&2
exit 1
