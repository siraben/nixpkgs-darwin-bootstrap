#!/bin/sh
## 25-libc — compile the full mes libc to a single libc.M1 with
## Darwin-mapped sources.
##
## Compiles every source in libc_SOURCES (the mes libc file list from
## the committed libc-config.sh fixture, expanded by mes's own
## configure-lib.sh) with mescc, mapping each lib/linux/ path to its
## lib/darwin/ counterpart when one exists, then merges all per-file
## M1 outputs into one code+data-sectioned libc.M1.  This is the libc
## that step 27 links into the first runnable tcc.
##
## Runs:     mes-m2 (built in step 18) interpreting mescc.scm (step
##           20) with nyacc (step 19); host awk — trust boundary —
##           partitions each M1 into code/data sections; Apple
##           /usr/bin sed/grep/install/cp for orchestration.
## Inputs:   sources/mescc-libc-fixtures/libc-config.sh,
##           target/mes-source (step 15; build-aux/configure-lib.sh
##           and the lib/ C sources, incl. the sources/mes-darwin
##           overlays staged there).
## Outputs:  target/share/libc/{libc.M1,sources.map,objects.list}
##           (the logs record the linux→darwin mapping and compile
##           order for audit).
## Verifies: libc.M1 defines :write, :_open3, :__sys_call4 and the
##           :ELF_data marker — syscall wrappers and the section
##           boundary survived the merge.
## Trust:    host awk performs the code/data split (semantic M1
##           surgery); the chain m1-split tool exists only from step
##           44c onward.
set -eu

mes_source="$TARGET/mes-source"
nyacc_dir="$TARGET/nyacc/share/nyacc-1.09.1"
work="$TARGET/work/libc"
rm -rf "$work"
mkdir -p "$work/m1" "$work/logs"
cd "$work"

mesLoadPath="$mes_source/module:$mes_source/mes/module:$nyacc_dir/module"

mescc() {
    MES_PREFIX="$mes_source" \
      GUILE_LOAD_PATH="$mesLoadPath" \
      srcdest="$mes_source/" \
      includedir="$mes_source/include" \
      libdir="$mes_source/lib" \
      M1="$TARGET/bin/M1" \
      HEX2="$TARGET/bin/hex2" \
      MES_STACK=6000000 \
      MES_ARENA=60000000 \
      MES_MAX_ARENA=60000000 \
      mes-m2 --no-auto-compile -e main \
        "$TARGET/share/mescc-trivial/mescc.scm" -- "$@"
}

cp "$SOURCES/mescc-libc-fixtures/libc-config.sh" config.sh
. ./config.sh
. "$mes_source/build-aux/configure-lib.sh"

## The mes file lists name lib/linux/ sources; use the lib/darwin/
## counterpart (staged in step 15) when it exists, so Darwin syscall
## stubs replace the Linux ones file-by-file.
map_source() {
    source="$1"
    case "$source" in
      lib/linux/x86_64-mes-mescc/*)
        mapped="lib/darwin/x86_64-mes-mescc/$(basename "$source")"
        ;;
      lib/linux/*)
        mapped="lib/darwin/${source#lib/linux/}"
        ;;
      *)
        mapped="$source"
        ;;
    esac
    if test -f "$mes_source/$mapped"; then
        printf '%s\n' "$mapped"
    else
        printf '%s\n' "$source"
    fi
}

compile_m1() {
    source="$1"
    mapped="$(map_source "$source")"
    source_path="$mes_source/$mapped"
    object_name="$(printf '%s\n' "$mapped" | sed -e 's|/|-|g' -e 's|[.]c$||').M1"
    output_path="m1/$object_name"
    echo "$source -> $mapped" >> logs/sources.map
    mescc -S -I "$mes_source/include" -D HAVE_CONFIG_H=1 \
        "$source_path" -o "$output_path" \
        > "$output_path.stdout" 2> "$output_path.stderr"
    test -s "$output_path"
    sed -i.bak '/^<$/d' "$output_path"
    rm -f "$output_path.bak"
    chmod 444 "$output_path"
    printf '%s\n' "$output_path" >> logs/objects.list
}

for source in $libc_SOURCES; do
    compile_m1 "$source"
done

## Merge pass 1: emit every object's code section.  globals.M1 is
## skipped here (it goes whole into the data region below).  exit.c
## uses :__call_at_exit as its split label instead of :ELF_data so the
## __call_at_exit table lands in the data segment.
while read -r object; do
    case "$object" in
      *lib-mes-globals.M1)
        ;;
      *)
        split_label='^:ELF_data$'
        if [ "$(basename "$object")" = "lib-stdlib-exit.M1" ]; then
            split_label='^:__call_at_exit$'
        fi
        awk '
          split_re != "" && $0 ~ split_re { data = 1; next }
          /^:ELF_data$/ { data = 1; next }
          /^:HEX2_data$/ { next }
          data != 1 { print }
        ' split_re="$split_label" "$object"
        ;;
    esac
done < logs/objects.list > logs/code.M1

## Merge pass 2: one :ELF_data/:HEX2_data boundary, then every
## object's data section in the same order.  The custom split label's
## line is kept ({print} in the match) so :__call_at_exit stays
## defined, in the data region.
{
    cat logs/code.M1
    echo ':ELF_data'
    echo ':HEX2_data'
    while read -r object; do
        case "$object" in
          *lib-mes-globals.M1)
            cat "$object"
            ;;
          *)
            split_label='^:ELF_data$'
            if [ "$(basename "$object")" = "lib-stdlib-exit.M1" ]; then
                split_label='^:__call_at_exit$'
            fi
            awk '
              split_re != "" && $0 ~ split_re { data = 1; print; next }
              /^:ELF_data$/ { data = 1; next }
              /^:HEX2_data$/ { next }
              data == 1 { print }
            ' split_re="$split_label" "$object"
            ;;
        esac
    done < logs/objects.list
} > libc.M1

grep -q '^:write' libc.M1
grep -q '^:_open3' libc.M1
grep -q '^:__sys_call4' libc.M1
grep -q '^:ELF_data' libc.M1

install -d "$TARGET/share/libc"
cp libc.M1 logs/sources.map logs/objects.list "$TARGET/share/libc/"
