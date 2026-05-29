#!/bin/sh
## 52-gcc46-cxx-install — install a working g++ (and cc1plus) from the
## gcc-4.6 c,c++ build (step 51), bypassing the xgcc driver which
## segfaults at startup (tcc codegen bug in its c,c++ spec tables).
##
## The g++ wrapper drives cc1plus + the tcc-compiled bootstrap-as filter
## + tcc-darwin-cc, exactly the pattern that compiles+links+runs C++.
set -eu

build="$TARGET/work/gcc46-cxx-all-gcc/build/gcc"
test -x "$build/cc1plus" || { echo "missing cc1plus (run step 51 first)" >&2; exit 1; }

out="$TARGET/gcc46-cxx"
rm -rf "$out"
mkdir -p "$out/bin"

## 1. cc1plus (the C++ front-end)
cp "$build/cc1plus" "$out/bin/cc1plus"
cp "$build/cc1" "$out/bin/cc1" 2>/dev/null || true

## 2. bootstrap-as filter, compiled by the chain's own tcc-darwin-cc
"$TARGET/bin/tcc-darwin-cc" "$SOURCES/gcc46-scripts/phase36-bootstrap-as.c" \
    -o "$out/bin/gcc46-cxx-as-filter"

## 3. g++ wrapper with placeholders substituted
sed -e "s|@CC1PLUS@|$out/bin/cc1plus|g" \
    -e "s|@ASFILTER@|$out/bin/gcc46-cxx-as-filter|g" \
    -e "s|@TCC@|$TARGET/bin/tcc-darwin-cc|g" \
    -e "s|@SYSROOT@|$TARGET/tcc-darwin-cc-root/include/tcc-darwin-bootstrap|g" \
    "$SOURCES/gcc46-scripts/gxx-bootstrap-wrapper.sh" > "$out/bin/g++"
chmod +x "$out/bin/g++"

## 4. Smoke test: a two-file self-contained C++ program must link + run.
work="$TARGET/work/gcc46-cxx-install"
rm -rf "$work"; mkdir -p "$work"; cd "$work"
printf 'int helper(){ return 35; }\n' > a.cc
printf 'int helper(); int main(){ return helper() + 7; }\n' > b.cc
"$out/bin/g++" -c a.cc -o a.o
"$out/bin/g++" -c b.cc -o b.o
"$out/bin/g++" a.o b.o -o prog
## prog intentionally exits 42; don't let set -e abort on that.
status=0
./prog || status=$?
test "$status" -eq 42 || { echo "g++ smoke test failed: exit $status (want 42)" >&2; exit 1; }
echo "gcc46-cxx install complete; g++ smoke test: C++ program exited 42 ✓"
