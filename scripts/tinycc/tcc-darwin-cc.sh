#!@SHELL@
set -euo pipefail

out=a.out
explicit_output=0
compile_only=0
preprocess_only=0
args=()
inputs=()
prepared_inputs=()
objects=()
archives=()
library_dirs=()
libraries=()
include_dirs=(@INCLUDE@)
cleanup_files=()
cleanup_dirs=()
emit_deps=0
dep_file=
dep_target=
dep_dummy_headers=0

while (($#)); do
  case "$1" in
    --version|-version|-V|-qversion)
      echo "tcc-darwin-cc bootstrap wrapper"
      case "$1" in
        -V|-qversion) exit 1 ;;
        *) exit 0 ;;
      esac
      ;;
    -c)
      compile_only=1
      args+=("$1")
      shift
      ;;
    -E)
      preprocess_only=1
      args+=("$1")
      shift
      ;;
    -o)
      out="$2"
      explicit_output=1
      if ((compile_only)); then
        args+=("-o" "$2")
      fi
      shift 2
      ;;
    -o*)
      out="${1#-o}"
      explicit_output=1
      if ((compile_only)); then
        args+=("$1")
      fi
      shift
      ;;
    -MD|-MMD)
      emit_deps=1
      shift
      ;;
    -MP)
      dep_dummy_headers=1
      shift
      ;;
    -MF)
      emit_deps=1
      dep_file="$2"
      shift 2
      ;;
    -MF*)
      emit_deps=1
      dep_file="${1#-MF}"
      shift
      ;;
    -MT|-MQ)
      dep_target="$2"
      shift 2
      ;;
    -MT*|-MQ*)
      dep_target="${1#-M?}"
      shift
      ;;
    -Wp,-MD,*)
      emit_deps=1
      dep_file="${1#-Wp,-MD,}"
      shift
      ;;
    -Wp,-MMD,*)
      emit_deps=1
      dep_file="${1#-Wp,-MMD,}"
      shift
      ;;
    -I)
      args+=("$1" "$2")
      include_dirs+=("$2")
      shift 2
      ;;
    -I*)
      args+=("$1")
      include_dirs+=("${1#-I}")
      shift
      ;;
    *.c)
      inputs+=("$1")
      shift
      ;;
    *.o)
      objects+=("$1")
      shift
      ;;
    *.a)
      case "$1" in
        /*) archives+=("$1") ;;
        *) archives+=("$(pwd)/$1") ;;
      esac
      shift
      ;;
    -L)
      library_dirs+=("$2")
      shift 2
      ;;
    -L*)
      library_dirs+=("${1#-L}")
      shift
      ;;
    -l*)
      libraries+=("${1#-l}")
      shift
      ;;
    *)
      args+=("$1")
      shift
      ;;
  esac
done

materialize_one_quote_header_dir() {
  local dir="$1" abs_dir key stamp_dir rel rel_dir header
  test -d "$dir" || return 0
  abs_dir="$(cd "$dir" && pwd)" || return 0
  [ "$abs_dir" = "$PWD" ] && return 0

  mkdir -p .tcc-darwin-header-stamps
  key="$(printf '%s\n' "$abs_dir" | cksum | awk '{ print $1 "-" $2 }')"
  stamp_dir=".tcc-darwin-header-stamps/$key"
  if [ -f "$stamp_dir/.complete" ]; then
    return 0
  fi

  if mkdir "$stamp_dir.lock" 2>/dev/null; then
    mkdir -p "$stamp_dir"
    for header in "$dir"/*.h "$dir"/*/*.h; do
      test -f "$header" || continue
      rel="${header#$dir/}"
      case "$rel" in
        */*)
          rel_dir="${rel%/*}"
          mkdir -p "$rel_dir"
          ;;
      esac
      test -e "$rel" || ln -s "$header" "$rel" 2>/dev/null || true
    done
    touch "$stamp_dir/.complete"
    rmdir "$stamp_dir.lock"
  else
    while [ ! -f "$stamp_dir/.complete" ]; do
      sleep 1
    done
  fi
}

materialize_quote_headers() {
  local dir
  for dir in "${include_dirs[@]}"; do
    materialize_one_quote_header_dir "$dir"
  done
}

prepare_source_inputs() {
  local index=0 work_dir
  for input in "${inputs[@]}"; do
    case "$input" in
      */*)
        work_dir="${tmp:-}"
        if [ -z "$work_dir" ]; then
          work_dir="$(mktemp -d .tcc-darwin-inputs.XXXXXX)"
          cleanup_dirs+=("$work_dir")
        fi
        local copy="$work_dir/input-$index.c"
        cp "$input" "$copy"
        cleanup_files+=("$copy")
        prepared_inputs+=("$copy")
        local input_dir
        input_dir="$(dirname "$input")"
        include_dirs+=("$input_dir")
        args+=("-I$input_dir")
        ;;
      *)
        prepared_inputs+=("$input")
        ;;
    esac
    index=$((index + 1))
  done
}

resolve_libraries() {
  local lib dir path found
  for lib in "${libraries[@]}"; do
    if [ "$lib" = m ]; then
      continue
    fi
    found=0
    for dir in "${library_dirs[@]}" .; do
      path="$dir/lib$lib.a"
      if [ -f "$path" ]; then
        case "$path" in
          /*) archives+=("$path") ;;
          *) archives+=("$(cd "$(dirname "$path")" && pwd)/$(basename "$path")") ;;
        esac
        found=1
        break
      fi
    done
    if [ "$found" = 0 ]; then
      echo "tcc-darwin-cc: library not found: -l$lib" >&2
      return 1
    fi
  done
}

process_symbol_file() {
  local file="$1"
  local kind name
  while IFS=$'\t' read -r kind name; do
    [ -n "${name:-}" ] || continue
    if [ "$kind" = D ]; then
      defined_symbols["$name"]=1
      unset 'unresolved_symbols[$name]'
    fi
  done < "$file"
  while IFS=$'\t' read -r kind name; do
    [ -n "${name:-}" ] || continue
    if [ "$kind" = U ] && [ -z "${defined_symbols[$name]+x}" ]; then
      unresolved_symbols["$name"]=1
    fi
  done < "$file"
}

add_object_symbols() {
  local object="$1"
  local index="$2"
  local symbols="$tmp/object-$index.symbols"
  @ELF_TO_M1@ --symbols "$object" > "$symbols"
  process_symbol_file "$symbols"
}

prepare_archive_cache() {
  local archive="$1"
  local cache_dir="$2"
  local checksum="$3"
  local prefix_key member member_index symbols

  if [ ! -f "$cache_dir/.prepared" ]; then
    if mkdir "$cache_dir.lock" 2>/dev/null; then
      rm -rf "$cache_dir"
      mkdir -p "$cache_dir/extract" "$cache_dir/code" "$cache_dir/data" "$cache_dir/symbols"
      (cd "$cache_dir/extract" && @AR@ -x "$archive")
      : > "$cache_dir/members.list"
      member_index=0
      for member in "$cache_dir/extract"/*.o; do
        test -f "$member" || continue
        symbols="$cache_dir/symbols/member-$member_index.tsv"
        @ELF_TO_M1@ --symbols "$member" > "$symbols"
        printf '%s\t%s\n' "$member_index" "$(basename "$member")" >> "$cache_dir/members.list"
        member_index=$((member_index + 1))
      done
      touch "$cache_dir/.prepared"
      rmdir "$cache_dir.lock"
    else
      while [ ! -f "$cache_dir/.prepared" ]; do
        sleep 1
      done
    fi
  fi
}

archive_member_needed() {
  local symbols="$1"
  local kind name
  while IFS=$'\t' read -r kind name; do
    [ -n "${name:-}" ] || continue
    if [ "$kind" = D ] && [ -n "${unresolved_symbols[$name]+x}" ]; then
      return 0
    fi
  done < "$symbols"
  return 1
}

add_selected_archive_member() {
  local cache_dir="$1"
  local prefix_key="$2"
  local member_index="$3"
  local member_name="$4"
  local member="$cache_dir/extract/$member_name"
  local m1="$cache_dir/member-$member_index.M1"
  local selected_key="$cache_dir:$member_index"

  [ -z "${selected_archive_members[$selected_key]+x}" ] || return 0
  selected_archive_members["$selected_key"]=1
  archive_selection_changed=1

  if [ ! -f "$cache_dir/code/member-$member_index.M1" ] || [ ! -f "$cache_dir/data/member-$member_index.M1" ]; then
    if mkdir "$cache_dir/member-$member_index.lock" 2>/dev/null; then
      @ELF_TO_M1@ --prefix "archive_${prefix_key}_${member_index}_" "$member" "$m1"
      awk '/^:ELF_data$/ { data = 1; next } /^:HEX2_data$/ { next } data != 1 { print }' "$m1" > "$cache_dir/code/member-$member_index.M1"
      awk '/^:ELF_data$/ { data = 1; next } /^:HEX2_data$/ { next } data == 1 { print }' "$m1" > "$cache_dir/data/member-$member_index.M1"
      rm -f "$m1"
      rmdir "$cache_dir/member-$member_index.lock"
    else
      while [ ! -f "$cache_dir/code/member-$member_index.M1" ] || [ ! -f "$cache_dir/data/member-$member_index.M1" ]; do
        sleep 1
      done
    fi
  fi

  code_files+=("$cache_dir/code/member-$member_index.M1")
  data_files+=("$cache_dir/data/member-$member_index.M1")
  process_symbol_file "$cache_dir/symbols/member-$member_index.tsv"
}

add_archive_m1_files() {
  local archive="$1"
  local archive_index="$2"
  local cache_root cache_key cache_dir checksum prefix_key member_index member_name symbols
  cache_root="${TCC_DARWIN_CACHE_DIR:-$PWD/.tcc-darwin-archive-cache}"
  mkdir -p "$cache_root"
  checksum="$(cksum "$archive" | awk '{ print $1 "-" $2 }')"
  cache_key="$(basename "$archive" | sed 's/[^A-Za-z0-9_.-]/_/g')-$checksum-resolve-v3"
  cache_dir="$cache_root/$cache_key"
  prefix_key="$(printf '%s' "$checksum" | tr -c 'A-Za-z0-9_' '_')"

  prepare_archive_cache "$archive" "$cache_dir" "$checksum"
  while IFS=$'\t' read -r member_index member_name; do
    [ -n "${member_index:-}" ] || continue
    symbols="$cache_dir/symbols/member-$member_index.tsv"
    if archive_member_needed "$symbols"; then
      add_selected_archive_member "$cache_dir" "$prefix_key" "$member_index" "$member_name"
    fi
  done < "$cache_dir/members.list"
}

add_archives() {
  local archive archive_index
  archive_selection_changed=1
  while [ "$archive_selection_changed" = 1 ]; do
    archive_selection_changed=0
    archive_index=0
    for archive in "${archives[@]}"; do
      add_archive_m1_files "$archive" "$archive_index"
      archive_index=$((archive_index + 1))
    done
  done
}

add_dependency() {
  local dep="$1"
  local existing
  for existing in "${deps[@]}"; do
    [ "$existing" = "$dep" ] && return 0
  done
  deps+=("$dep")
}

collect_dependency_headers() {
  local input line header resolved dir input_dir
  deps=()
  for input in "${inputs[@]}"; do
    test -f "$input" || continue
    add_dependency "$input"
    input_dir="$(dirname "$input")"
    while IFS= read -r line; do
      case "$line" in
        *'#include "'*'"'*)
          header="${line#*#include \"}"
          header="${header%%\"*}"
          resolved=
          if [ -f "$input_dir/$header" ]; then
            resolved="$input_dir/$header"
          else
            for dir in "${include_dirs[@]}"; do
              if [ -f "$dir/$header" ]; then
                resolved="$dir/$header"
                break
              fi
            done
          fi
          [ -n "$resolved" ] && add_dependency "$resolved"
          ;;
      esac
    done < "$input"
  done
}

write_dependency_file() {
  ((emit_deps)) || return 0
  [ -n "$dep_file" ] || return 0
  local target="$dep_target"
  local dep
  if [ -z "$target" ]; then
    if [ -n "$out" ] && ((compile_only)); then
      target="$out"
    elif [ "${#inputs[@]}" -eq 1 ]; then
      target="$(basename "${inputs[0]}")"
      target="${target%.c}.o"
    else
      target="a.out"
    fi
  fi
  mkdir -p "$(dirname "$dep_file")"
  collect_dependency_headers
  {
    printf '%s:' "$target"
    for dep in "${deps[@]}"; do
      printf ' %s' "$dep"
    done
    printf '\n'
    if ((dep_dummy_headers)); then
      for dep in "${deps[@]}"; do
        [ "$dep" = "${inputs[0]:-}" ] && continue
        printf '%s:\n' "$dep"
      done
    fi
  } > "$dep_file"
}

cleanup() {
  for file in "${cleanup_files[@]}"; do
    rm -f "$file"
  done
  for dir in "${cleanup_dirs[@]}"; do
    rm -rf "$dir"
  done
}
trap cleanup EXIT

if ((compile_only || preprocess_only)); then
  prepare_source_inputs
  if ((compile_only && !preprocess_only && explicit_output == 0 && ${#inputs[@]} == 1)); then
    source_base="$(basename "${inputs[0]}")"
    args+=("-o" "${source_base%.c}.o")
  fi
  materialize_quote_headers
  @TCC@ "${args[@]}" -I@INCLUDE@ "${prepared_inputs[@]}" "${objects[@]}"
  write_dependency_file
  exit "$?"
fi

if [ "${#inputs[@]}" -eq 0 ] && [ "${#objects[@]}" -eq 0 ] && [ "${#archives[@]}" -eq 0 ]; then
  echo "tcc-darwin-cc: no input files" >&2
  exit 1
fi

tmp="$(mktemp -d)"
trap 'cleanup; rm -rf "$tmp"' EXIT

prepare_source_inputs
materialize_quote_headers
object_index=0
for input in "${prepared_inputs[@]}"; do
  object="$tmp/source-$object_index.o"
  @TCC@ -c "${args[@]}" -I@INCLUDE@ "$input" -o "$object"
  objects+=("$object")
  object_index=$((object_index + 1))
done
resolve_libraries

code_files=()
data_files=()
declare -A defined_symbols=()
declare -A unresolved_symbols=()
declare -A selected_archive_members=()
object_index=0
for object in "${objects[@]}"; do
  add_object_symbols "$object" "$object_index"
  object_index=$((object_index + 1))
done
add_archives
object_index=0
for object in "${objects[@]}"; do
  m1="$tmp/object-$object_index.M1"
  @ELF_TO_M1@ --prefix "obj_$object_index"_ "$object" "$m1"
  awk '/^:ELF_data$/ { data = 1; next } /^:HEX2_data$/ { next } data != 1 { print }' "$m1" > "$tmp/object-$object_index.code.M1"
  awk '/^:ELF_data$/ { data = 1; next } /^:HEX2_data$/ { next } data == 1 { print }' "$m1" > "$tmp/object-$object_index.data.M1"
  code_files+=("$tmp/object-$object_index.code.M1")
  data_files+=("$tmp/object-$object_index.data.M1")
  object_index=$((object_index + 1))
done

{
  cat @CRT1@
  cat @SYSCALLS@
  for file in "${code_files[@]}"; do cat "$file"; done
  awk '/^:ELF_data$/ { data = 1; next } /^:HEX2_data$/ { next } data != 1 { print }' @LIBC_M1@
  echo ':ELF_data'
  echo ':HEX2_data'
  for file in "${data_files[@]}"; do cat "$file"; done
  awk '/^:ELF_data$/ { data = 1; next } /^:HEX2_data$/ { next } data == 1 { print }' @LIBC_M1@
  # C++ static-init array brackets. crt1-tcc-sysv.M1 references __bake_init_start
  # /__bake_init_end and walks [start,end) calling each ctor before main. This
  # wrapper compiles only C (no global constructors), so emit an EMPTY array
  # (start == end → the crt1 loop is a no-op). Without these labels the link
  # fails "Target label __bake_init_start is not valid": crt1 added the
  # references in commit b016ef9 (the bake bash3 wrapper emits a real array).
  echo ':__bake_init_start'
  echo ':__bake_init_end'
} > "$tmp/combined.M1"

# Cross-object synth labels: elf64-to-m1's per-object blanket only DEFINES a
# small predictable set of `:<sym>_plus_<off>` labels, so a reference to a far
# offset it never relocates (e.g. a data-array slot in gcc's xgcc/cc1) is left
# undefined and the binary's data relocations come out wrong — xgcc then runs
# but prints NOTHING (-dumpversion/-E/-dM all empty), failing the gcc-4.6
# `s-macro_list` step.  Scan the whole link for referenced-but-undefined
# `<sym>_plus_<hex>` labels and inject each def at byte (<sym> + hex).  No-op
# (verbatim) for small links.  Flatten to one token per line first (`tr`) so awk
# streams instead of building a multi-GB array on gcc's huge data lines.
synth_inject() { awk -f @SYNTH_INJECT@ "$1"; }
if tr -s ' \t' '\n' < "$tmp/combined.M1" > "$tmp/combined.tok.M1" \
   && synth_inject "$tmp/combined.tok.M1" > "$tmp/combined.inj.M1"; then
  mv "$tmp/combined.inj.M1" "$tmp/combined.M1"
fi
rm -f "$tmp/combined.tok.M1"

# Two-tier Mach-O layout: try the SMALL/fast layout first (minimal text
# padding → fast); fall back to LARGE only when the text overruns it
# (m1-to-hex2 prints "align target before current address" and exits 1),
# e.g. for gcc-4.6 cc1plus.  Keeps configure conftests fast.
macho_large="@MACHO@"
macho_small="$(dirname "@MACHO@")/MACHO-amd64-smalldata.hex2"
if @M1_TO_HEX2@ --architecture amd64 --little-endian --base-address 0x600400 --align-label ELF_data=0x1700000 -f "$tmp/combined.M1" -o "$tmp/combined.hex2" 2>/dev/null; then
  macho="$macho_small"
  linkeditOffset="$((0x1100000 + 0x2000000))"
else
  @M1_TO_HEX2@ --architecture amd64 --little-endian --base-address 0x600400 --align-label ELF_data=0x2E00000 -f "$tmp/combined.M1" -o "$tmp/combined.hex2"
  macho="$macho_large"
  linkeditOffset="$((0x2800000 + 0x2000000))"
fi
@HEX2@ --architecture amd64 --little-endian --base-address 0x600000 \
  -f "$macho" -f "$tmp/combined.hex2" -o "$out"
dd if=/dev/zero of="$out" bs=1 count=1 seek="$((linkeditOffset - 1))" conv=notrunc 2>/dev/null
chmod +x "$out"
source @SIGNING@
sign "$out"
