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

mode=link
out=a.out
cc1args=(-quiet -I"$SYSROOT")
objs=()
srcs=()

while [ $# -gt 0 ]; do
  case "$1" in
    -c) mode=object; shift ;;
    -S) mode=asm; shift ;;
    -o) out="$2"; shift 2 ;;
    -o*) out="${1#-o}"; shift ;;
    -I|-isystem|-iquote|-idirafter|-include|-D|-U) cc1args+=("$1" "$2"); shift 2 ;;
    -I*|-D*|-U*|-O*|-g*|-f*|-std=*|-W*|-nostdinc*) cc1args+=("$1"); shift ;;
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
  "$CC1PLUS" "${cc1args[@]}" "$s" -o "$tmp/c$i.s"
  if [ "$mode" = asm ]; then
    "$ASFILTER" < "$tmp/c$i.s" > "${out:-${s%.*}.s}"
    continue
  fi
  "$ASFILTER" < "$tmp/c$i.s" > "$tmp/c$i.f.s"
  if [ "$mode" = object ] && [ "${#srcs[@]}" -eq 1 ]; then
    "$TCC" -c "$tmp/c$i.f.s" -o "$out"
    exit 0
  fi
  o="${s%.*}.o"
  "$TCC" -c "$tmp/c$i.f.s" -o "$o"
  objs+=("$o")
done

[ "$mode" = link ] || exit 0
"$TCC" "${objs[@]}" -o "$out"
