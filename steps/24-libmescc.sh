#!/bin/sh
## 24-libmescc — compile libmescc.M1 (globals + syscall-internal).
##
## Smallest mescc library build: two mes lib sources compiled to M1
## and merged into one code+data-sectioned file.  Exercises the same
## mescc pipeline and section-merge scheme that steps 25/26 apply to
## the full libc lists.  No later step reads libmescc.M1.
##
## Runs:     mes-m2 (built in step 18) interpreting mescc.scm (step
##           20) with nyacc (step 19); host awk — trust boundary —
##           partitions each M1 into code/data sections; Apple
##           /usr/bin sed/grep/install/cp for orchestration.
## Inputs:   target/mes-source/lib/mes/globals.c and
##           lib/darwin/x86_64-mes-mescc/syscall-internal.c.
## Outputs:  target/share/libmescc/libmescc.M1.
## Verifies: merged M1 defines :__raise and :__sys_call_internal —
##           both translation units made it into the output.
## Trust:    host awk performs the code/data split (semantic M1
##           surgery); the chain m1-split tool exists only from step
##           44c onward.
set -eu

mes_source="$TARGET/mes-source"
nyacc_dir="$TARGET/nyacc/share/nyacc-1.09.1"
work="$TARGET/work/libmescc"
rm -rf "$work"
mkdir -p "$work/m1"
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

compile_m1() {
    source_path="$1"
    output_path="$2"
    mescc -S -I "$mes_source/include" -D HAVE_CONFIG_H=1 \
        "$source_path" -o "$output_path" \
        > "$output_path.stdout" 2> "$output_path.stderr"
    test -s "$output_path"
    sed -i.bak '/^<$/d' "$output_path"
    rm -f "$output_path.bak"
    chmod 444 "$output_path"
}

compile_m1 "$mes_source/lib/mes/globals.c" m1/globals.M1
compile_m1 "$mes_source/lib/darwin/x86_64-mes-mescc/syscall-internal.c" m1/syscall-internal.M1

## Merge into one M1 with a single :ELF_data/:HEX2_data boundary:
## syscall-internal's code, the markers, then globals.M1 verbatim and
## syscall-internal's data.  mescc emits per-file section markers; a
## combined link needs exactly one code→data transition.
{
    awk '
        /^:ELF_data$/ { data = 1; next }
        /^:HEX2_data$/ { next }
        data != 1 { print }
    ' m1/syscall-internal.M1
    echo ':ELF_data'
    echo ':HEX2_data'
    cat m1/globals.M1
    awk '
        /^:ELF_data$/ { data = 1; next }
        /^:HEX2_data$/ { next }
        data == 1 { print }
    ' m1/syscall-internal.M1
} > libmescc.M1

grep -q '^:__raise' libmescc.M1
grep -q '^:__sys_call_internal' libmescc.M1

install -d "$TARGET/share/libmescc"
cp libmescc.M1 "$TARGET/share/libmescc/"
