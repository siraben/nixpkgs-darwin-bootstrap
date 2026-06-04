#!/usr/bin/env bash
set -euo pipefail

phase35=$1
phase36=$2
phase34=$3
as_filter_src=$4   # C source for the Mach-O/GAS->tcc assembly translator
python=$5
elf_to_m1=$6
out=$7
gcc_version=$8

target=x86_64-apple-darwin
gcc_lib="$out/lib/gcc/$target/$gcc_version"
gcc_exec="$out/libexec/gcc/$target/$gcc_version"
merged_include="$out/include/gcc46-bootstrap"
bootstrap_share="$out/share/darwin-bootstrap"

mkdir -p "$out/bin" "$gcc_lib/include" "$gcc_exec" "$merged_include" "$bootstrap_share"
cp "$phase35/share/darwin-bootstrap/work/build/gcc/xgcc" "$gcc_exec/xgcc"
cp "$phase35/share/darwin-bootstrap/work/build/gcc/cc1" "$gcc_exec/cc1"
cp "$phase35/share/darwin-bootstrap/work/build/gcc/cpp" "$gcc_exec/cpp"
cp -R "$phase35/share/darwin-bootstrap/work/build/gcc/include/." "$gcc_lib/include/"
for include_dir in "$gcc_lib/include" "$phase34/include/tcc-darwin-bootstrap"; do
  for include_entry in "$include_dir"/*; do
    [ -e "$include_entry" ] || continue
    include_name="$(basename "$include_entry")"
    if [ "$include_dir" = "$gcc_lib/include" ] && [ "$include_name" = stdint.h ]; then
      continue
    fi
    [ -e "$merged_include/$include_name" ] || [ -L "$merged_include/$include_name" ] || ln -s "$include_entry" "$merged_include/$include_name"
  done
done
cp "$phase36/lib/gcc/$target/$gcc_version/libgcc.a" "$gcc_lib/libgcc.a"
cp "$phase36/lib/gcc/$target/$gcc_version/libgcov.a" "$gcc_lib/libgcov.a"
cp -R "$phase36/lib/gcc/$target/$gcc_version/libgcc-objects" "$gcc_lib/libgcc-objects"
mkdir -p "$gcc_lib/libgcc-symbols"
for object in "$gcc_lib/libgcc-objects"/*.o; do
  "$elf_to_m1" --symbols "$object" 2>/dev/null | sort -u > "$gcc_lib/libgcc-symbols/$(basename "$object").tsv"
done

## Compile the assembly-translation filter with the chain's own compiler
## (tcc-darwin-cc) rather than depending on the host's awk.
as_filter="$out/bin/gcc46-bootstrap-as-filter"
"$phase34/bin/tcc-darwin-cc" "$as_filter_src" -o "$as_filter"

cat > "$out/bin/gcc46-bootstrap-as" <<EOF_AS
#!$BASH
set -euo pipefail

out=
input=
while [ "\$#" -gt 0 ]; do
  case "\$1" in
    -o) shift; out="\$1" ;;
    -arch) shift ;;
    -force_cpusubtype_ALL|-mmacosx-version-min=*|-march=*|-mtune=*|-Qy|-Qn|--32|--64) ;;
    -) input=- ;;
    *.s|*.S) input="\$1" ;;
    *) ;;
  esac
  shift || true
done

if [ -z "\$out" ]; then
  echo "gcc46-bootstrap-as: missing -o" >&2
  exit 1
fi

tmpdir="\$(mktemp -d "\${TMPDIR:-/tmp}/gcc46-bootstrap-as.XXXXXX")"
trap 'rm -rf "\$tmpdir"' EXIT HUP INT TERM
if [ -z "\$input" ] || [ "\$input" = - ]; then
  cat > "\$tmpdir/input.s"
  input="\$tmpdir/input.s"
fi
"$as_filter" < "\$input" > "\$tmpdir/filtered.s"
exec "$phase34/bin/tcc-darwin-cc" -c "\$tmpdir/filtered.s" -o "\$out"
EOF_AS
chmod +x "$out/bin/gcc46-bootstrap-as"

cat > "$out/bin/gcc" <<EOF_GCC
#!$BASH
## No 'nounset': macOS ships bash 3.2, which errors on "\${arr[@]}" when
## the array is empty (e.g. no extra compiler args) under set -u.
set -eo pipefail

xgcc="$gcc_exec/xgcc"
gcc_exec="$gcc_exec"
merged_include="$merged_include"
assembler="$out/bin/gcc46-bootstrap-as"
linker="$phase34/bin/tcc-darwin-cc"
sysroot="$phase34/include/tcc-darwin-bootstrap"
python="$python"
elf_to_m1="$elf_to_m1"
libgcc_objects="$gcc_lib/libgcc-objects"
libgcc_symbols="$gcc_lib/libgcc-symbols"
object_format="\${GCC46_BOOTSTRAP_OBJECT_FORMAT:-elf}"
# Quarantine: the dormant macho/host-source code paths must NOT silently fall
# back to the host as/cc/ld.  Default these empty (instead of $(command -v ...))
# so the guards below ("requires GCC46_BOOTSTRAP_AS/MACHO_CC/HOST_CC") refuse
# loudly unless a developer EXPLICITLY opts in.  Faithful bake uses
# object_format=elf and never touches them.
macho_as="\${GCC46_BOOTSTRAP_AS:-}"
macho_linker="\${GCC46_BOOTSTRAP_MACHO_CC:-}"
host_generated_cc="\${GCC46_BOOTSTRAP_HOST_CC:-}"

mode=link
out_file=
explicit_output=0
compiler_args=()
link_args=()
sources=()
asm_sources=()
objects=()
selected_libgcc_objects=()

while [ "\$#" -gt 0 ]; do
  case "\$1" in
    --version|-dump*|-print*|-v|-V|-qversion)
      exec "\$xgcc" -B"\$gcc_exec/" "\$@"
      ;;
    -c)
      mode=object
      shift
      ;;
    -S)
      mode=asm
      shift
      ;;
    -E)
      exec env MACOSX_DEPLOYMENT_TARGET=10.6 "\$xgcc" -B"\$gcc_exec/" --sysroot="\$sysroot" -isystem "\$merged_include" "\$@"
      ;;
    -o)
      out_file="\$2"
      explicit_output=1
      shift 2
      ;;
    -o*)
      out_file="\${1#-o}"
      explicit_output=1
      shift
      ;;
    -I|-isystem|-iquote|-idirafter|-include|-D|-U|-MF|-MT|-MQ)
      compiler_args+=("\$1" "\$2")
      shift 2
      ;;
    -I*|-D*|-U*|-O*|-g*|-f*|-m*|-W*|-std=*|-ansi|-pedantic|-nostdinc)
      case "\$1" in
        -Werror|-Werror=implicit-function-declaration|-Werror=implicit-int) ;;
        *) compiler_args+=("\$1") ;;
      esac
      shift
      ;;
    -L|-L*|-l*|*.a)
      link_args+=("\$1")
      if [ "\$1" = -L ]; then
        link_args+=("\$2")
        shift 2
      else
        shift
      fi
      ;;
    *.c)
      sources+=("\$1")
      shift
      ;;
    *.s|*.S)
      asm_sources+=("\$1")
      shift
      ;;
    *.o)
      objects+=("\$1")
      shift
      ;;
    *)
      compiler_args+=("\$1")
      shift
      ;;
  esac
done

tmpdir="\$(mktemp -d "\${TMPDIR:-/tmp}/gcc46-bootstrap.XXXXXX")"
if [ "\${GCC46_BOOTSTRAP_KEEP_TEMPS:-0}" = 1 ]; then
  echo "gcc: keeping temporary directory \$tmpdir" >&2
  trap 'echo "gcc: kept temporary directory '\$tmpdir'" >&2' EXIT HUP INT TERM
else
  trap 'rm -rf "\$tmpdir"' EXIT HUP INT TERM
fi

ensure_symlink() {
  local target="\$1"
  local link="\$2"
  if [ -e "\$link" ] || [ -L "\$link" ]; then
    return 0
  fi
  ln -s "\$target" "\$link" 2>/dev/null || [ -e "\$link" ] || [ -L "\$link" ]
}

expand_config_overlay() {
  local config_link="\$tmpdir/config"
  local config_target config_entry config_name sub_entry sub_name
  [ -L "\$config_link" ] || return 0
  config_target="\$(readlink "\$config_link")"
  [ -d "\$config_target" ] || return 0
  rm -f "\$config_link"
  mkdir -p "\$config_link"
  for config_entry in "\$config_target"/*; do
    [ -e "\$config_entry" ] || continue
    config_name="\${config_entry##*/}"
    if [ -d "\$config_entry" ]; then
      mkdir -p "\$config_link/\$config_name"
      ensure_symlink .. "\$config_link/\$config_name/config"
      for sub_entry in "\$config_entry"/*; do
        [ -e "\$sub_entry" ] || continue
        sub_name="\${sub_entry##*/}"
        ensure_symlink "\$sub_entry" "\$config_link/\$config_name/\$sub_name"
      done
    else
      ensure_symlink "\$config_entry" "\$config_link/\$config_name"
    fi
  done
}

overlay_dir_contents() {
  local source_dir="\$1"
  local overlay_dir="\$2"
  local entry entry_name sub_entry sub_name overlay_name
  overlay_name="\${overlay_dir##*/}"
  mkdir -p "\$overlay_dir"
  for entry in "\$source_dir"/*; do
    [ -e "\$entry" ] || continue
    entry_name="\${entry##*/}"
    if [ -d "\$entry" ]; then
      mkdir -p "\$overlay_dir/\$entry_name"
      if [ "\$overlay_name" = config ]; then
        ensure_symlink .. "\$overlay_dir/\$entry_name/config"
      fi
      for sub_entry in "\$entry"/*; do
        [ -e "\$sub_entry" ] || continue
        sub_name="\${sub_entry##*/}"
        ensure_symlink "\$sub_entry" "\$overlay_dir/\$entry_name/\$sub_name"
      done
    else
      ensure_symlink "\$entry" "\$overlay_dir/\$entry_name"
    fi
  done
}

is_known_source_dir() {
  case "\$1" in
    config|c-family|cp|ada|java|objc|go|fortran|lto|libcpp) return 0 ;;
    *) return 1 ;;
  esac
}

is_overlay_include() {
  local path="\$1"
  local name="\${path##*/}"
  if [ -d "\$path" ]; then
    case "\$name" in
      sys|bits|machine|arch) return 0 ;;
      *) is_known_source_dir "\$name" && return 0 ;;
    esac
    return 1
  fi
  case "\$name" in
    *.h|*.hh|*.hpp|*.hxx|*.inc|*.def|*.md|*.opt) return 0 ;;
    *) return 1 ;;
  esac
}

is_source_neighbor() {
  local path="\$1"
  local name="\${path##*/}"
  is_overlay_include "\$path" && return 0
  case "\$name" in
    *.c|*.cc|*.cpp|*.cxx|*.S|*.s|*.x) return 0 ;;
    *) return 1 ;;
  esac
}

compile_to_asm() {
  local input="\$1"
  local asm_out="\$2"
  local compile_input="\$input"
  local input_dir source_dir source_dir_name source_dir_target gcc_source_root source_entry source_name source_target include_dir include_entry include_name include_target
  local input_dir_args=()
  local source_overlay related_source_subdir root_overlay_entry root_overlay_name filtered_arg
  local effective_compiler_args=()
  local staged_source=0
  source_dir_name=
  case "\$input" in
    */*)
      staged_source=1
      input_dir="\${input%/*}"
      input_dir_args=(-I"\$input_dir")
      compile_input="\$tmpdir/\${input##*/}"
      cp "\$input" "\$compile_input"
      source_dir="\$input_dir"
      source_dir_name="\${source_dir##*/}"
      case "\$source_dir" in
        /*) source_dir_target="\$source_dir" ;;
        *) source_dir_target="\$PWD/\$source_dir" ;;
      esac
      if [ -d "\$source_dir_target" ] && is_known_source_dir "\$source_dir_name"; then
        overlay_dir_contents "\$source_dir_target" "\$tmpdir/\$source_dir_name"
        gcc_source_root="\${source_dir_target%/*}"
        for gcc_source_subdir in config c-family cp ada java objc go fortran lto libcpp; do
          [ -d "\$gcc_source_root/\$gcc_source_subdir" ] || continue
          overlay_dir_contents "\$gcc_source_root/\$gcc_source_subdir" "\$tmpdir/\$gcc_source_subdir"
        done
        for gcc_source_subdir in libcpp include libdecnumber; do
          [ -d "\$gcc_source_root/../\$gcc_source_subdir" ] || continue
          if [ "\$gcc_source_subdir" = libcpp ]; then
            overlay_dir_contents "\$gcc_source_root/../\$gcc_source_subdir" "\$tmpdir/\$gcc_source_subdir"
            [ -d "\$gcc_source_root/../\$gcc_source_subdir/include" ] && overlay_dir_contents "\$gcc_source_root/../\$gcc_source_subdir/include" "\$tmpdir/\$gcc_source_subdir"
          else
            ensure_symlink "\$gcc_source_root/../\$gcc_source_subdir" "\$tmpdir/\$gcc_source_subdir"
          fi
        done
        compile_input="\$tmpdir/\$source_dir_name/\${input##*/}"
      fi
      for source_entry in "\$source_dir"/*; do
        [ -e "\$source_entry" ] || continue
        is_source_neighbor "\$source_entry" || continue
        source_name="\${source_entry##*/}"
        case "\$source_entry" in
          /*) source_target="\$source_entry" ;;
          *) source_target="\$PWD/\$source_entry" ;;
        esac
        ensure_symlink "\$source_target" "\$tmpdir/\$source_name"
      done
      expand_config_overlay
      input_dir_args=(-I"\$tmpdir" "\${input_dir_args[@]}")
      ;;
    *)
      if [ "\${input##*/}" != conftest.c ] && [ -f "\$input" ] && { [ -d config ] || [ -f config.h ]; }; then
        staged_source=1
        compile_input="\$tmpdir/\${input##*/}"
        cp "\$input" "\$compile_input"
        input_dir_args=(-I"\$tmpdir")
      fi
      ;;
  esac
  if [ "\$staged_source" -eq 1 ]; then
    for include_dir in -I"\$merged_include" "\${compiler_args[@]}" "\${input_dir_args[@]}"; do
      case "\$include_dir" in
        -I*) include_dir="\${include_dir#-I}" ;;
        *) continue ;;
      esac
      [ -d "\$include_dir" ] || continue
      for include_entry in "\$include_dir"/*; do
        [ -e "\$include_entry" ] || continue
        is_overlay_include "\$include_entry" || continue
        include_name="\${include_entry##*/}"
        case "\$include_entry" in
          /*) include_target="\$include_entry" ;;
          *) include_target="\$PWD/\$include_entry" ;;
        esac
        if [ -d "\$include_entry" ] && is_known_source_dir "\$include_name"; then
          if [ "\$include_target" != "\$tmpdir/\$include_name" ]; then
            [ -L "\$tmpdir/\$include_name" ] && rm -f "\$tmpdir/\$include_name" 2>/dev/null || true
            overlay_dir_contents "\$include_target" "\$tmpdir/\$include_name"
          fi
          if is_known_source_dir "\$source_dir_name" && [ -d "\$tmpdir/\$source_dir_name" ]; then
            [ -L "\$tmpdir/\$source_dir_name/\$include_name" ] && rm -f "\$tmpdir/\$source_dir_name/\$include_name"
            if [ "\$include_name" = "\$source_dir_name" ]; then
              ensure_symlink . "\$tmpdir/\$source_dir_name/\$include_name"
            else
              ensure_symlink "../\$include_name" "\$tmpdir/\$source_dir_name/\$include_name"
            fi
          fi
          continue
        fi
        ensure_symlink "\$include_target" "\$tmpdir/\$include_name"
        if is_known_source_dir "\$source_dir_name" && [ -d "\$tmpdir/\$source_dir_name" ]; then
          ensure_symlink "\$include_target" "\$tmpdir/\$source_dir_name/\$include_name"
        fi
      done
    done
    if is_known_source_dir "\$source_dir_name" && [ -d "\$tmpdir/\$source_dir_name" ]; then
      source_overlay="\$tmpdir/\$source_dir_name"
      for related_source_subdir in config c-family cp ada java objc go fortran lto libcpp include libdecnumber; do
        [ -e "\$tmpdir/\$related_source_subdir" ] || [ -L "\$tmpdir/\$related_source_subdir" ] || continue
        [ -L "\$source_overlay/\$related_source_subdir" ] && rm -f "\$source_overlay/\$related_source_subdir" 2>/dev/null || true
        if [ "\$related_source_subdir" = "\$source_dir_name" ]; then
          ensure_symlink . "\$source_overlay/\$related_source_subdir"
        else
          ensure_symlink "../\$related_source_subdir" "\$source_overlay/\$related_source_subdir"
        fi
      done
    fi
    for source_overlay in "\$tmpdir"/config "\$tmpdir"/c-family "\$tmpdir"/cp "\$tmpdir"/ada "\$tmpdir"/java "\$tmpdir"/objc "\$tmpdir"/go "\$tmpdir"/fortran "\$tmpdir"/lto "\$tmpdir"/libcpp; do
      [ -d "\$source_overlay" ] || continue
      [ -L "\$source_overlay" ] && continue
      source_dir_name="\${source_overlay##*/}"
      for related_source_subdir in config c-family cp ada java objc go fortran lto libcpp include libdecnumber; do
        [ -e "\$tmpdir/\$related_source_subdir" ] || [ -L "\$tmpdir/\$related_source_subdir" ] || continue
        [ -L "\$source_overlay/\$related_source_subdir" ] && rm -f "\$source_overlay/\$related_source_subdir" 2>/dev/null || true
        if [ "\$related_source_subdir" = "\$source_dir_name" ]; then
          ensure_symlink . "\$source_overlay/\$related_source_subdir"
        else
          ensure_symlink "../\$related_source_subdir" "\$source_overlay/\$related_source_subdir"
        fi
      done
      for root_overlay_entry in "\$tmpdir"/*; do
        [ -f "\$root_overlay_entry" ] || [ -L "\$root_overlay_entry" ] || continue
        is_overlay_include "\$root_overlay_entry" || continue
        root_overlay_name="\${root_overlay_entry##*/}"
        ensure_symlink "../\$root_overlay_name" "\$source_overlay/\$root_overlay_name"
      done
    done
    for core_header in stdarg.h stddef.h stdbool.h float.h; do
      if [ -e "\$merged_include/\$core_header" ]; then
        [ -L "\$tmpdir/\$core_header" ] && rm -f "\$tmpdir/\$core_header"
        [ -e "\$tmpdir/\$core_header" ] || cp "\$merged_include/\$core_header" "\$tmpdir/\$core_header"
      fi
      if is_known_source_dir "\$source_dir_name" && [ -d "\$tmpdir/\$source_dir_name" ]; then
        if [ -e "\$merged_include/\$core_header" ]; then
          [ -L "\$tmpdir/\$source_dir_name/\$core_header" ] && rm -f "\$tmpdir/\$source_dir_name/\$core_header"
          [ -e "\$tmpdir/\$source_dir_name/\$core_header" ] || cp "\$merged_include/\$core_header" "\$tmpdir/\$source_dir_name/\$core_header"
        fi
      fi
    done
    expand_config_overlay
  fi
  effective_compiler_args=("\${compiler_args[@]}")
  case "\${input##*/}" in
    insn-*.c)
      effective_compiler_args=()
      for filtered_arg in "\${compiler_args[@]}"; do
        case "\$filtered_arg" in
          -g|-g[0-9]*|-ggdb*) continue ;;
        esac
        effective_compiler_args+=("\$filtered_arg")
      done
      ;;
  esac
  MACOSX_DEPLOYMENT_TARGET=10.6 "\$xgcc" -B"\$gcc_exec/" \\
    --sysroot="\$sysroot" -isystem "\$merged_include" \\
    -fno-asynchronous-unwind-tables -fno-unwind-tables -mno-sse2 \\
    "\${input_dir_args[@]}" "\${effective_compiler_args[@]}" \\
    -S "\$compile_input" -o "\$asm_out"
  rewrite_dependency_files "\$compile_input" "\$input"
}

host_compile_source() {
  local input="\$1"
  local object_out="\$2"
  local filtered_arg
  local host_args=()
  local host_overlay="\$tmpdir/host-cc-overlay"
  [ "\$object_format" = macho ] || return 1
  case "\${input##*/}" in
    insn-*.c)
      [ "\${GCC46_BOOTSTRAP_HOST_CC_GENERATED:-0}" = 1 ] || [ "\${GCC46_BOOTSTRAP_HOST_CC_SOURCES:-0}" = 1 ] || return 1
      ;;
    *)
      [ "\${GCC46_BOOTSTRAP_HOST_CC_SOURCES:-0}" = 1 ] || return 1
      ;;
  esac
  if [ -z "\$host_generated_cc" ]; then
    echo "gcc: host source compile shortcut requires GCC46_BOOTSTRAP_HOST_CC or host cc" >&2
    exit 1
  fi
  for filtered_arg in "\${compiler_args[@]}"; do
    case "\$filtered_arg" in
      -g|-g[0-9]*|-ggdb*) continue ;;
      -D_FORTIFY_SOURCE|-D_FORTIFY_SOURCE=*|-U_FORTIFY_SOURCE) continue ;;
    esac
    host_args+=("\$filtered_arg")
  done
  mkdir -p "\$host_overlay/sys"
  cat > "\$host_overlay/stdio.h" <<'HOST_STDIO'
#pragma once
#include_next <stdio.h>
#undef snprintf
#undef vsnprintf
#undef sprintf
#undef vsprintf
HOST_STDIO
  cat > "\$host_overlay/sys/resource.h" <<'HOST_RESOURCE'
#pragma once
#undef rlim_t
#include_next <sys/resource.h>
HOST_RESOURCE
  cat > "\$host_overlay/signal.h" <<'HOST_SIGNAL'
#pragma once
#include_next <signal.h>
#define HAVE_PSIGNAL 1
HOST_SIGNAL
  cat > "\$host_overlay/string.h" <<'HOST_STRING'
#pragma once
#include_next <string.h>
#define HAVE_STRSIGNAL 1
#define HAVE_DECL_STRSIGNAL 1
HOST_STRING
  cat > "\$host_overlay/stdint.h" <<'HOST_STDINT'
#pragma once
#include <sys/_types/_int8_t.h>
#include <sys/_types/_int16_t.h>
#include <sys/_types/_int32_t.h>
#include <sys/_types/_int64_t.h>
#include <_types/_uint8_t.h>
#include <_types/_uint16_t.h>
#include <_types/_uint32_t.h>
#include <_types/_uint64_t.h>
#include <sys/_types/_intptr_t.h>
#include <sys/_types/_uintptr_t.h>
#include <_types/_intmax_t.h>
#include <_types/_uintmax_t.h>
#ifndef _STDINT_H_
#define _STDINT_H_
#endif
typedef int8_t int_least8_t;
typedef int16_t int_least16_t;
typedef int32_t int_least32_t;
typedef int64_t int_least64_t;
typedef uint8_t uint_least8_t;
typedef uint16_t uint_least16_t;
typedef uint32_t uint_least32_t;
typedef uint64_t uint_least64_t;
typedef int8_t int_fast8_t;
typedef int64_t int_fast16_t;
typedef int64_t int_fast32_t;
typedef int64_t int_fast64_t;
typedef uint8_t uint_fast8_t;
typedef uint64_t uint_fast16_t;
typedef uint64_t uint_fast32_t;
typedef uint64_t uint_fast64_t;
#ifndef SIZE_MAX
#define SIZE_MAX ((size_t)-1)
#endif
HOST_STDINT
  MACOSX_DEPLOYMENT_TARGET=10.8 "\$host_generated_cc" -arch x86_64 \
    -mmacosx-version-min=10.8 \
    -fno-asynchronous-unwind-tables -fno-unwind-tables -fno-stack-protector \
    -Wno-error -Wno-format-security \
    -I"\$host_overlay" \
    "\${host_args[@]}" \
    -c "\$input" -o "\$object_out" || return 1
  return 0
}

assemble_to_object() {
  local input="\$1"
  local object_out="\$2"
  case "\$object_format" in
    elf)
      "\$assembler" "\$input" -o "\$object_out"
      ;;
    macho)
      if [ -z "\$macho_as" ]; then
        echo "gcc: GCC46_BOOTSTRAP_OBJECT_FORMAT=macho requires GCC46_BOOTSTRAP_AS or host as" >&2
        exit 1
      fi
      "\$macho_as" -arch x86_64 "\$input" -o "\$object_out"
      ;;
    *)
      echo "gcc: unsupported GCC46_BOOTSTRAP_OBJECT_FORMAT=\$object_format" >&2
      exit 1
      ;;
  esac
}

rewrite_dependency_files() {
  local tmp_source="\$1"
  local real_source="\$2"
  local arg dep_file content i
  for ((i = 0; i < \${#compiler_args[@]}; i++)); do
    arg="\${compiler_args[\$i]}"
    case "\$arg" in
      -MF)
        i=\$((i + 1))
        dep_file="\${compiler_args[\$i]}"
        ;;
      -MF*)
        dep_file="\${arg#-MF}"
        ;;
      *)
        continue
        ;;
    esac
    [ -f "\$dep_file" ] || continue
    content="\$(cat "\$dep_file")"
    content="\${content//\$tmp_source/\$real_source}"
    content="\${content//\$tmpdir\\//}"
    printf '%s\n' "\$content" > "\$dep_file"
  done
}

normalize_symbols() {
  sort -u "\$tmpdir/defined.raw" > "\$tmpdir/defined.sorted"
  sort -u "\$tmpdir/unresolved.raw" > "\$tmpdir/unresolved.all"
  comm -23 "\$tmpdir/unresolved.all" "\$tmpdir/defined.sorted" > "\$tmpdir/unresolved.sorted"
}

# Extract column 2 of a D/U symbol TSV (\$1 = D|U, \$2 = file).  Prefer the
# chain-built tsv-col (sources/tools/tsv-col.c, on PATH as \$TARGET/bin once
# step 44d ran) over host awk for this libgcc symbol selection.
dusym() {
  if command -v tsv-col >/dev/null 2>&1; then tsv-col "\$1" < "\$2"
  else awk -F '\t' -v t="\$1" '\$1 == t { print \$2 }' "\$2"; fi
}

add_object_symbols() {
  local object="\$1"
  local symbols="\$tmpdir/symbols-\${object##*/}.tsv"
  "\$elf_to_m1" --symbols "\$object" 2>/dev/null | sort -u > "\$symbols"
  dusym D "\$symbols" >> "\$tmpdir/defined.raw"
  dusym U "\$symbols" >> "\$tmpdir/unresolved.raw"
  normalize_symbols
}

select_libgcc_objects() {
  : > "\$tmpdir/defined.raw"
  : > "\$tmpdir/unresolved.raw"
  : > "\$tmpdir/defined.sorted"
  : > "\$tmpdir/unresolved.sorted"
  : > "\$tmpdir/selected-libgcc.list"

  local object symbol_file changed needed_defs member_name member_object
  for object in "\${objects[@]}"; do
    add_object_symbols "\$object"
  done

  if [ ! -s "\$tmpdir/unresolved.sorted" ]; then
    return 0
  fi

  changed=1
  while [ "\$changed" = 1 ]; do
    changed=0
    for symbol_file in "\$libgcc_symbols"/*.tsv; do
      member_name="\${symbol_file##*/}"
      member_name="\${member_name%.tsv}"
      member_object="\$libgcc_objects/\$member_name"
      grep -qxF "\$member_object" "\$tmpdir/selected-libgcc.list" 2>/dev/null && continue

      dusym D "\$symbol_file" | sort -u > "\$tmpdir/member-defs.sorted"
      needed_defs="\$(comm -12 "\$tmpdir/member-defs.sorted" "\$tmpdir/unresolved.sorted" | head -1 || true)"
      if [ -n "\$needed_defs" ]; then
        selected_libgcc_objects+=("\$member_object")
        printf '%s\n' "\$member_object" >> "\$tmpdir/selected-libgcc.list"
        dusym D "\$symbol_file" >> "\$tmpdir/defined.raw"
        dusym U "\$symbol_file" >> "\$tmpdir/unresolved.raw"
        normalize_symbols
        changed=1
      fi
    done
  done
}

if [ "\$mode" = asm ]; then
  if [ "\${#sources[@]}" -ne 1 ]; then
    echo "gcc: bootstrap -S currently expects exactly one C input" >&2
    exit 1
  fi
  if [ -z "\$out_file" ]; then
    base="\${sources[0]##*/}"
    out_file="\${base%.c}.s"
  fi
  compile_to_asm "\${sources[0]}" "\$out_file"
  exit 0
fi

if [ "\$mode" = object ]; then
  total_inputs=\$((\${#sources[@]} + \${#asm_sources[@]}))
  if [ "\$total_inputs" -ne 1 ]; then
    echo "gcc: bootstrap -c currently expects exactly one input" >&2
    exit 1
  fi
  if [ -z "\$out_file" ]; then
    if [ "\${#sources[@]}" -eq 1 ]; then
      base="\${sources[0]##*/}"
      out_file="\${base%.c}.o"
    else
      base="\${asm_sources[0]##*/}"
      out_file="\${base%.*}.o"
    fi
  fi
  if [ "\${#sources[@]}" -eq 1 ]; then
    if ! host_compile_source "\${sources[0]}" "\$out_file"; then
      compile_to_asm "\${sources[0]}" "\$tmpdir/input.s"
      assemble_to_object "\$tmpdir/input.s" "\$out_file"
    fi
  else
    assemble_to_object "\${asm_sources[0]}" "\$out_file"
  fi
  exit 0
fi

object_index=0
for source in "\${sources[@]}"; do
  asm_file="\$tmpdir/source-\$object_index.s"
  object_file="\$tmpdir/source-\$object_index.o"
  compile_to_asm "\$source" "\$asm_file"
  assemble_to_object "\$asm_file" "\$object_file"
  objects+=("\$object_file")
  object_index=\$((object_index + 1))
done

for source in "\${asm_sources[@]}"; do
  object_file="\$tmpdir/asm-\$object_index.o"
  assemble_to_object "\$source" "\$object_file"
  objects+=("\$object_file")
  object_index=\$((object_index + 1))
done

if [ -z "\$out_file" ]; then
  out_file=a.out
fi

if [ "\${#objects[@]}" -eq 0 ]; then
  echo "gcc: no input files" >&2
  exit 1
fi

if [ "\$object_format" = macho ]; then
  if [ -z "\$macho_linker" ]; then
    echo "gcc: GCC46_BOOTSTRAP_OBJECT_FORMAT=macho link mode requires GCC46_BOOTSTRAP_MACHO_CC or host cc" >&2
    exit 1
  fi
  if [ -n "\$macho_as" ]; then
    cat > "\$tmpdir/darwin-stdio.s" <<'ASM'
	.data
	.p2align 3
	.globl _stdin
_stdin:
	.quad 0
	.globl _stdout
_stdout:
	.quad 0
	.globl _stderr
_stderr:
	.quad 0
	.text
	.p2align 4
_darwin_bootstrap_stdio_init:
	movq ___stdinp@GOTPCREL(%rip), %rax
	movq (%rax), %rax
	movq %rax, _stdin(%rip)
	movq ___stdoutp@GOTPCREL(%rip), %rax
	movq (%rax), %rax
	movq %rax, _stdout(%rip)
	movq ___stderrp@GOTPCREL(%rip), %rax
	movq (%rax), %rax
	movq %rax, _stderr(%rip)
	ret
	.globl _fputc_unlocked
_fputc_unlocked:
	jmp _fputc
	.globl _fputs_unlocked
_fputs_unlocked:
	jmp _fputs
	.globl _fread_unlocked
_fread_unlocked:
	jmp _fread
	.globl _fwrite_unlocked
_fwrite_unlocked:
	jmp _fwrite
	.section __DATA,__mod_init_func,mod_init_funcs
	.p2align 3
	.quad _darwin_bootstrap_stdio_init
ASM
    "\$macho_as" -arch x86_64 "\$tmpdir/darwin-stdio.s" -o "\$tmpdir/darwin-stdio.o"
    objects+=("\$tmpdir/darwin-stdio.o")
  fi
  exec "\$macho_linker" -arch x86_64 -mmacosx-version-min=10.8 "\${objects[@]}" "\${link_args[@]}" -o "\$out_file"
fi

select_libgcc_objects

exec "\$linker" "\${objects[@]}" "\${link_args[@]}" "\${selected_libgcc_objects[@]}" -o "\$out_file"
EOF_GCC
chmod +x "$out/bin/gcc"
ln -s gcc "$out/bin/cc"
ln -s gcc "$out/bin/gcc-4.6"

if [ "${PHASE37_SKIP_SELF_TESTS:-0}" = 1 ]; then
  exit 0
fi

cat > smoke.c <<'C'
extern int puts(const char *);
int helper(int x) { return x + 40; }
int main(void) { puts("gcc46 bootstrap smoke"); return helper(2); }
C

"$out/bin/gcc" -S smoke.c -o "$bootstrap_share/smoke.s"
grep -q '^_main:' "$bootstrap_share/smoke.s"
"$out/bin/gcc" -c smoke.c -o smoke.o
test "$(od -An -tx1 -N4 smoke.o | tr -d ' \n')" = "7f454c46"
if grep -q 'libgcc[.]a' "$out/bin/gcc"; then
  echo "phase37 gcc wrapper still links libgcc archive" >&2
  exit 1
fi
set +e
"$out/bin/gcc" smoke.c -o smoke > "$bootstrap_share/smoke-link.stdout" 2> "$bootstrap_share/smoke-link.stderr"
link_status=$?
set -e
test "$link_status" = 0
set +e
./smoke > "$bootstrap_share/smoke-run.stdout" 2> "$bootstrap_share/smoke-run.stderr"
smoke_status=$?
set -e
test "$smoke_status" = 42

cat > int128.c <<'C'
typedef __int128 ti;
ti product(ti x, ti y) { return x * y; }
int main(void) { return (int) product(6, 7); }
C
set +e
"$out/bin/gcc" int128.c -o int128 > "$bootstrap_share/int128-link.stdout" 2> "$bootstrap_share/int128-link.stderr"
int128_link_status=$?
set -e
test "$int128_link_status" = 0
set +e
./int128 > "$bootstrap_share/int128-run.stdout" 2> "$bootstrap_share/int128-run.stderr"
int128_status=$?
set -e
test "$int128_status" = 42

cat > multi-helper.c <<'C'
int helper(int x) { return x + 40; }
C
cat > multi-main.c <<'C'
int helper(int);
int main(void) { return helper(2); }
C
"$out/bin/gcc" -c multi-helper.c -o multi-helper.o
"$out/bin/gcc" -c multi-main.c -o multi-main.o
set +e
"$out/bin/gcc" multi-main.o multi-helper.o -o multi > "$bootstrap_share/multi-link.stdout" 2> "$bootstrap_share/multi-link.stderr"
multi_link_status=$?
set -e
test "$multi_link_status" = 0
set +e
./multi > "$bootstrap_share/multi-run.stdout" 2> "$bootstrap_share/multi-run.stderr"
multi_status=$?
set -e
test "$multi_status" = 42

cp smoke.c smoke.o smoke int128.c int128 multi-helper.c multi-main.c multi-helper.o multi-main.o multi "$bootstrap_share/"
