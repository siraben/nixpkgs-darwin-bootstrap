#!/bin/sh
# Goal test for the from-seed gcc-10: xgcc must compile AND run real C.
# Exits 0 on success (program returned 7), non-zero otherwise.
#
# Deliberately does NOT source gcc10-env.sh: that env sets
# MACOSX_DEPLOYMENT_TARGET=10.6 (needed to *build* gcc-10), but propagating it
# here makes the modern system `ld` mis-handle the final hello link
# ("library '...' not found").  The test only needs xgcc + SDKROOT; xgcc's own
# specs carry the right deployment target.  The empty stub libgcc*.a (step 55)
# satisfy -lgcc; SDKROOT supplies -lSystem.  That stub dependency is the current
# impurity boundary — real libgcc built by this xgcc would remove it.
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
if [ "$rc" -eq 7 ]; then
  echo "GOAL PASS: from-seed xgcc-10 compiled & ran C (returned 7)"
  exit 0
else
  echo "GOAL FAIL: program returned $rc (want 7)" >&2
  exit 1
fi
