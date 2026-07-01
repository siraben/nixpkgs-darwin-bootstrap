#!/usr/bin/env bash
set -euo pipefail

cc1=${GCC46_PHASE36_CC1:?}
assembler=${GCC46_PHASE36_AS:?}
version=${GCC46_PHASE36_VERSION:?}

mode=link
out=
input=
compiler_args=()

while [ "$#" -gt 0 ]; do
  case "$1" in
    --version|-dumpversion)
      echo "xgcc (GCC) $version"
      exit 0
      ;;
    -v)
      compiler_args+=("-version")
      shift
      ;;
    -E)
      mode=preprocess
      shift
      ;;
    -S)
      mode=assembly
      shift
      ;;
    -c)
      mode=object
      shift
      ;;
    -o)
      out=$2
      shift 2
      ;;
    -o*)
      out=${1#-o}
      shift
      ;;
    -B|-isystem|-iquote|-idirafter|-include|-imacros|-MF|-MT|-MQ)
      case "$1" in
        -B) ;;
        *) compiler_args+=("$1" "$2") ;;
      esac
      shift 2
      ;;
    -B*|-pipe|-dynamic|-static|--sysroot=*)
      shift
      ;;
    -I*|-D*|-U*|-O*|-g*|-f*|-m*|-W*|-std=*|-ansi|-pedantic|-nostdinc)
      compiler_args+=("$1")
      shift
      ;;
    -M|-MM|-MD|-MMD|-MP)
      compiler_args+=("$1")
      shift
      ;;
    *.c|*.i|*.s|*.S)
      input=$1
      shift
      ;;
    *)
      shift
      ;;
  esac
done

if [ -z "$input" ]; then
  echo "xgcc-bootstrap: no input files" >&2
  exit 1
fi

case "$input" in
  /*) ;;
  *) input="$PWD/$input" ;;
esac

case "$input" in
  *.s)
    if [ "$mode" = object ]; then
      [ -n "$out" ] || out="${input%.s}.o"
      exec "$assembler" "$input" -o "$out"
    fi
    ;;
  *.S)
    ;;
esac

common_args=(
  -quiet
  -D__DYNAMIC__
  -fPIC
  -mmacosx-version-min=10.6
  -mtune=core2
  "${compiler_args[@]}"
)

cc1_input=$input
case "$(basename "$input")" in
  conftest.c|conftest.i)
    staged_tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/gcc46-xgcc-src.XXXXXX")"
    trap 'rm -rf "$staged_tmpdir"' EXIT HUP INT TERM
    cc1_input="$staged_tmpdir/$(basename "$input")"
    cp "$input" "$cc1_input"
    ;;
esac

case "$mode" in
  preprocess)
    if [ -n "$out" ]; then
      exec "$cc1" -E "${common_args[@]}" "$cc1_input" -o "$out"
    fi
    exec "$cc1" -E "${common_args[@]}" "$cc1_input"
    ;;
  assembly)
    [ -n "$out" ] || out="${input%.*}.s"
    exec "$cc1" "${common_args[@]}" "$cc1_input" -o "$out"
    ;;
  object|link)
    if [ -z "$out" ]; then
      if [ "$mode" = link ]; then
        out=a.out
      else
        out="${input%.*}.o"
      fi
    fi
    tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/gcc46-xgcc.XXXXXX")"
    trap 'rm -rf "$tmpdir"' EXIT HUP INT TERM
    asm="$tmpdir/input.s"
    "$cc1" "${common_args[@]}" "$cc1_input" -o "$asm"
    "$assembler" "$asm" -o "$out"
    [ "$mode" != link ] || chmod +x "$out"
    ;;
esac
