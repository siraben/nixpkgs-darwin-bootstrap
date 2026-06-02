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
      # Not finding a -l library is not fatal: system libs (-lc/-lm/-ldl/...)
      # are provided by the cat'd libc M1, and any genuinely-missing symbol is
      # caught later by hex2 ("Target label ... not valid").  Warn and continue
      # so a harmless -l flag forwarded by a caller can't abort the whole link.
      echo "tcc-darwin-cc: warning: library not found, skipping: -l$lib" >&2
    fi
  done
}

process_symbol_file() {
  # Update the global defined/unresolved symbol sets with one member's symbols,
  # using sorted-set operations (sort/comm) instead of a per-symbol grep loop.
  # The old loop ran `grep -vFx`/`grep -qFx` once PER symbol against files that
  # grow to ~600K lines for a gcc cc1 link -> O(n^2), ~hours, and the repeated
  # rewrites churned the disk.  This is near-linear C-speed and keeps both set
  # files sorted (LC_ALL=C) so comm below is valid.  Semantics preserved exactly:
  #   defined    := defined ∪ memberD
  #   unresolved := (unresolved \ memberD) ∪ (memberU \ defined_new)
  local file="$1"
  local d="$tmp/.psf_d" u="$tmp/.psf_u" t1="$tmp/.psf_t1" t2="$tmp/.psf_t2"
  LC_ALL=C awk -F'\t' '$1 == "D" && $2 != "" { print $2 }' "$file" | LC_ALL=C sort -u > "$d"
  LC_ALL=C awk -F'\t' '$1 == "U" && $2 != "" { print $2 }' "$file" | LC_ALL=C sort -u > "$u"
  LC_ALL=C sort -u "$defined_symbols_file" "$d" > "$t1"
  mv "$t1" "$defined_symbols_file"
  LC_ALL=C comm -23 "$unresolved_symbols_file" "$d" > "$t1"
  LC_ALL=C comm -23 "$u" "$defined_symbols_file" > "$t2"
  LC_ALL=C sort -u "$t1" "$t2" > "$unresolved_symbols_file.n"
  mv "$unresolved_symbols_file.n" "$unresolved_symbols_file"
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
  # A member is needed iff any symbol it DEFINES is currently unresolved.
  # Sorted-set intersection (comm -12) instead of a per-symbol grep scan of the
  # growing unresolved file.  unresolved_symbols_file is kept sorted (LC_ALL=C)
  # by process_symbol_file.
  local symbols="$1"
  local d="$tmp/.amn_d"
  LC_ALL=C awk -F'\t' '$1 == "D" && $2 != "" { print $2 }' "$symbols" | LC_ALL=C sort -u > "$d"
  LC_ALL=C comm -12 "$d" "$unresolved_symbols_file" | LC_ALL=C grep -q .
}

add_selected_archive_member() {
  local cache_dir="$1"
  local prefix_key="$2"
  local member_index="$3"
  local member_name="$4"
  local member="$cache_dir/extract/$member_name"
  local m1="$cache_dir/member-$member_index.M1"
  local selected_key="$cache_dir:$member_index"

  ! grep -qFx "$selected_key" "$selected_archive_members_file" || return 0
  echo "$selected_key" >> "$selected_archive_members_file"
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
defined_symbols_file="$tmp/defined_symbols"; : > "$defined_symbols_file"
unresolved_symbols_file="$tmp/unresolved_symbols"; : > "$unresolved_symbols_file"
selected_archive_members_file="$tmp/selected_archive_members"; : > "$selected_archive_members_file"
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
} > "$tmp/combined.M1"

# Precise cross-object synth labels: elf64-to-m1's per-object blanket only
# DEFINES a small predictable set of `:<sym>_plus_<off>` labels, so a reference
# to a far offset it never relocates (e.g. a C++ vtable slot) is left undefined.
# Scan the whole link for referenced-but-undefined `<sym>_plus_<hex>` labels and
# inject each def at byte (<sym> + hex).  No-op (verbatim pass-through) when the
# link has no such gap, which is the case for nearly every conftest/small link.
if awk -f @SYNTH_INJECT@ "$tmp/combined.M1" > "$tmp/combined.inj.M1"; then
  mv "$tmp/combined.inj.M1" "$tmp/combined.M1"
fi

# Dynamic Mach-O layout: m1-to-hex2 --auto-data-align pads the code only up
# to its page-rounded end (minimal padding → tiny/fast conftests) and
# reports the chosen __DATA vmaddr + data end on stderr.  We then size the
# Mach-O segments to the ACTUAL binary by generating a per-link load-command
# template from MACHO-amd64-lowdata.hex2.  (Replaces the old fixed small/
# large two-tier layout, which padded every binary to 18MB/46MB.)
lowdata="$(dirname "@MACHO@")/MACHO-amd64-lowdata.hex2"
_meta="$(@M1_TO_HEX2@ --architecture amd64 --little-endian --base-address 0x600400 --auto-data-align -f "$tmp/combined.M1" -o "$tmp/combined.hex2" 2>&1 1>/dev/null)"
_dv="$(printf '%s\n' "$_meta" | sed -n 's/.*DATA_VMADDR=\([0-9A-Fa-f][0-9A-Fa-f]*\).*/\1/p')"
_de="$(printf '%s\n' "$_meta" | sed -n 's/.*DATA_END=\([0-9A-Fa-f][0-9A-Fa-f]*\).*/\1/p')"
data_vmaddr=$((16#$_dv))
data_end=$((16#$_de))
text_vmsize=$((data_vmaddr - 6291456))           # 6291456 = 0x600000
text_sect_size=$((text_vmsize - 1024))           # header is 0x400
data_size=$((data_end - data_vmaddr))
data_vmsize=$(( ((data_size + 65535) / 65536) * 65536 ))
if [ "$data_vmsize" -eq 0 ]; then data_vmsize=65536; fi
data_fileoff=$text_vmsize
linkedit_vmaddr=$((data_vmaddr + data_vmsize))
linkedit_fileoff=$((data_fileoff + data_vmsize))
le8() {
  local v=$1 i b o=""
  for i in 0 1 2 3 4 5 6 7; do
    b=$(( (v >> (8 * i)) & 255 ))
    o="$o$(printf '%02x ' "$b")"
  done
  printf '%s' "${o% }"
}
awk -v n10="$(le8 6291456) $(le8 "$text_vmsize")" \
    -v n11="$(le8 0) $(le8 "$text_vmsize")" \
    -v n15="$(le8 6292480) $(le8 "$text_sect_size")" \
    -v n19="$(le8 0) $(le8 "$data_vmaddr")" \
    -v n20="$(le8 "$data_vmsize") $(le8 "$data_fileoff")" \
    -v n21="$(le8 "$data_vmsize") 03 00 00 00 03 00 00 00" \
    -v n24="$(le8 "$linkedit_vmaddr") $(le8 4096)" \
    -v n25="$(le8 "$linkedit_fileoff") $(le8 0)" '
  NR==10{print n10;next} NR==11{print n11;next} NR==15{print n15;next}
  NR==19{print n19;next} NR==20{print n20;next} NR==21{print n21;next}
  NR==24{print n24;next}
  NR==25{print n25;next} {print}' "$lowdata" > "$tmp/macho.hex2"
@HEX2@ --architecture amd64 --little-endian --base-address 0x600000 \
  -f "$tmp/macho.hex2" -f "$tmp/combined.hex2" -o "$out"
dd if=/dev/zero of="$out" bs=1 count=1 seek="$((linkedit_fileoff - 1))" conv=notrunc 2>/dev/null
chmod +x "$out"
source @SIGNING@
sign "$out"
