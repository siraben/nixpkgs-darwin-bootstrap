#!/bin/bash
## gxx-bootstrap-wrapper — a g++ driver that BYPASSES the gcc-4.6 xgcc
## driver (which segfaults at startup when built c,c++ by tcc) and drives
## cc1plus + the bootstrap-as filter + tcc-darwin-cc directly.  Same idea
## as phase37-driver.sh's gcc wrapper, but for C++.
##
## A bake step substitutes the @PLACEHOLDERS@.  Validated: separate
## compilation of a multi-file self-contained C++ program links + runs.
## (libstdc++ headers/lib are NOT yet wired — add -I/-L for them once the
## libstdc++ step exists.)
set -eo pipefail

CC1PLUS="@CC1PLUS@"          # gcc-4.6 cc1plus
ASFILTER="@ASFILTER@"        # tcc-compiled phase36-bootstrap-as
TCC="@TCC@"                  # tcc-darwin-cc (assemble + link)
SYSROOT="@SYSROOT@"          # tcc-darwin-bootstrap C headers
LIBSTDCXX="@LIBSTDCXX@"      # gcc-4.6 libstdc++ build dir (headers + .a)
LIBSUPCXX="@LIBSUPCXX@"      # libsupc++ source headers (<new>, <exception>, <typeinfo>)

mode=link
out=     # empty until -o seen; default per-mode (basename.s/.o, a.out) below
# C headers go in the SYSTEM include chain (searched after -I dirs) so that
# libstdc++'s `#include_next <stdlib.h>` etc. resolve to them rather than
# being skipped (they sit before the libstdc++ headers if added via -I).
# -mno-sse3: keep gcc on the SSE2 baseline so float->int uses cvttsd2si
# (tcc's assembler has SSE2 but not the SSE3 fisttp instruction; adding fisttp
# to tcc's opcode table overflowed the mes-m2 bootstrap stage).
cc1args=(-quiet -mno-sse3 -I"$LIBSTDCXX/include" -I"$LIBSTDCXX/include/x86_64-apple-darwin" -I"$LIBSUPCXX" -isystem "$SYSROOT")
objs=()
srcs=()

## Driver queries autotools/configure makes — answer them ourselves with
## canned values (the real xgcc driver crashes; cc1plus doesn't grok them).
case "${1:-}" in
  --version|-dumpversion) echo "4.6.4"; exit 0 ;;
  -dumpmachine) echo "x86_64-apple-darwin"; exit 0 ;;
  -print-prog-name=*) echo "${1#-print-prog-name=}"; exit 0 ;;
  -print-search-dirs) echo "install: $(dirname "$0")/"; exit 0 ;;
esac

while [ $# -gt 0 ]; do
  case "$1" in
    --version|-dumpversion) echo "4.6.4"; exit 0 ;;
    -dumpmachine) echo "x86_64-apple-darwin"; exit 0 ;;
    -E) cc1args+=(-E); mode=preprocess; shift ;;
    -c) mode=object; shift ;;
    -S) mode=asm; shift ;;
    -o) out="$2"; shift 2 ;;
    -o*) out="${1#-o}"; shift ;;
    -I|-isystem|-iquote|-idirafter|-include|-D|-U) cc1args+=("$1" "$2"); shift 2 ;;
    -W*) shift ;;   # drop warnings: gcc-10's libstdc++ passes -W flags (e.g. -Wabi=2) that gcc-4.6 cc1plus rejects; warnings never affect codegen
    -I*|-D*|-U*|-O*|-g*|-f*|-std=*|-nostdinc*) cc1args+=("$1"); shift ;;
    -L*|-l*|*.a) shift ;;   # link args ignored for now (static, no libs yet)
    *.cc|*.cpp|*.cxx|*.C|*.c++) srcs+=("$1"); shift ;;
    *.o) objs+=("$1"); shift ;;
    *) cc1args+=("$1"); shift ;;
  esac
done

tmp="$(mktemp -d "${TMPDIR:-/tmp}/gxx-bootstrap.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

i=0
for s in "${srcs[@]}"; do
  i=$((i + 1))
  ## -E: cc1plus integrated preprocess; emit preprocessed text (configure
  ## uses `g++ -E` for header/feature checks). cc1plus -E writes to stdout.
  if [ "$mode" = preprocess ]; then
    if [ -z "$out" ]; then
      "$CC1PLUS" "${cc1args[@]}" "$s"
    else
      "$CC1PLUS" "${cc1args[@]}" "$s" -o "$out"
    fi
    continue
  fi
  "$CC1PLUS" "${cc1args[@]}" "$s" -o "$tmp/c$i.s"
  if [ "$mode" = asm ]; then
    "$ASFILTER" < "$tmp/c$i.s" > "${out:-${s%.*}.s}"
    continue
  fi
  "$ASFILTER" < "$tmp/c$i.s" > "$tmp/c$i.f.s"
  if [ "$mode" = object ] && [ "${#srcs[@]}" -eq 1 ]; then
    "$TCC" -c "$tmp/c$i.f.s" -o "${out:-${s%.*}.o}"
    exit 0
  fi
  o="${s%.*}.o"
  "$TCC" -c "$tmp/c$i.f.s" -o "$o"
  objs+=("$o")
done

[ "$mode" = link ] || exit 0
## Link against the chain-built libstdc++ + libsupc++ (partial archive; the
## few float-formatting/locale TUs that needed SSE3 are excluded — not used by
## gcc-10).  bake-ar archives can't be -l/-L resolved, so pass the .a paths.
libs=()
[ -f "$LIBSTDCXX/libstdc++.a" ] && libs+=("$LIBSTDCXX/libstdc++.a")
[ -f "$LIBSTDCXX/libsupc++/.libs/libsupc++.a" ] && libs+=("$LIBSTDCXX/libsupc++/.libs/libsupc++.a")
"$TCC" "${objs[@]}" "${libs[@]}" -o "${out:-a.out}"
