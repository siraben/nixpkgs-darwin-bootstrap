#!/bin/sh
# Goal test for the from-seed gcc-10: xgcc must compile AND run real C,
# including explicit calls to the core libgcc's 128-bit division helpers.
# Exits 0 on success (both programs returned 7), non-zero otherwise.
#
# Run by a maintainer after step 55 (step 55's final message points here);
# not part of the build.sh step sequence.  Env contract: ROOT/TARGET/
# GCC10_BUILD all optional — each defaults from the script's own location.
# Trust: the compile is pure chain (xgcc/cc1), but the final executable
# link goes through xgcc to Apple's system `as`/`ld` with SDKROOT for
# -lSystem — trust boundary: the chain has no native Mach-O executable
# linker for gcc output, so the goal test's link step is host-performed.
#
# Deliberately does NOT source gcc10-env.sh: that env sets
# MACOSX_DEPLOYMENT_TARGET=10.6 (needed to *build* gcc-10), but propagating it
# here makes the modern system `ld` mis-handle the final hello link
# ("library '...' not found").  The test only needs xgcc + SDKROOT; xgcc's own
# specs carry the right deployment target. Step 55 builds the core libgcc.a
# with this xgcc; libgcc_eh/libgcc_s/libemutls_w remain symbol-less Mach-O
# stubs. SDKROOT supplies -lSystem. The host assembler/linker and runtime
# stubs remain documented trust boundaries.
set -u

ROOT="${ROOT:-$(cd -- "$(dirname -- "$0")/.." && pwd)}"
TARGET="${TARGET:-$ROOT/target}"
B="${GCC10_BUILD:-$TARGET/work/gcc10-all-gcc/build}"

test -x "$B/gcc/xgcc" || { echo "GOAL FAIL: no xgcc at $B/gcc/xgcc (run steps 54/55)" >&2; exit 2; }

t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
cat > "$t/hello.c" <<'C'
static int fib(int n){ return n < 2 ? n : fib(n-1) + fib(n-2); }
int main(void){ return fib(10) == 55 ? 7 : 1; }
C

SDK=$(xcrun --show-sdk-path 2>/dev/null || echo /)
SDKROOT="$SDK" "$B/gcc/xgcc" -B"$B/gcc/" -O1 "$t/hello.c" -o "$t/hello" || {
  echo "GOAL FAIL: xgcc did not compile/link" >&2; exit 2; }
"$t/hello"; rc=$?
if [ "$rc" -ne 7 ]; then
  echo "GOAL FAIL: program returned $rc (want 7)" >&2
  exit 1
fi

# Exercise arithmetic wider than the host's hardware division instruction.
# libSystem also exports these helpers, so successful linking alone is not
# proof: require the link map to show extraction from our core archive.
cat > "$t/runtime.c" <<'C'
extern __int128 __divti3(__int128, __int128);
extern unsigned __int128 __udivti3(unsigned __int128, unsigned __int128);
int main(void) {
    __int128 n = (((__int128)1) << 100) + 6;
    __int128 q = (((__int128)1) << 99) + 3;
    if (__divti3(n, 2) != q) return 1;
    if (__divti3(-n, 2) != -q) return 2;
    if (__udivti3((unsigned __int128)n, 2) != (unsigned __int128)q) return 3;
    return 7;
}
C
SDKROOT="$SDK" "$B/gcc/xgcc" -B"$B/gcc/" -O0 "$t/runtime.c" \
  -Wl,-map,"$t/runtime.map" -o "$t/runtime" || {
  echo "GOAL FAIL: core libgcc test did not compile/link" >&2; exit 2; }
for member in _divdi3.o _udivdi3.o; do
  if ! grep -F "$B/gcc/libgcc.a($member)" "$t/runtime.map" >/dev/null; then
    echo "GOAL FAIL: core libgcc test did not load $member from the bootstrap archive" >&2
    exit 1
  fi
done
"$t/runtime"; rc=$?
if [ "$rc" -ne 7 ]; then
  echo "GOAL FAIL: core libgcc test returned $rc (want 7)" >&2
  exit 1
fi
echo "GOAL PASS: from-seed xgcc-10 compiled & ran C and core libgcc division (both returned 7)"
