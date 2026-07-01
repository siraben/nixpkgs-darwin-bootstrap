#!/bin/sh
## 21-libc-mini — first mescc-built libc layer: compile a minimal
## libc to M1 and prove it links and runs.  Mirrors
## mescc-libc/libc-mini.nix.
##
## The tinycc phases (22+) need C library code compiled by mescc.
## This step compiles ten mes libc sources (write/puts/exit/strlen
## and the Darwin _exit/_write syscall stubs) with mescc.scm,
## regroups their code and data sections into a single libc-mini.M1
## archive, then links a puts-smoke fixture against it into a
## runnable Mach-O binary.
##
## Runs:     mes-m2 (step 18) driving mescc.scm (step 20) for every
##           C-to-M1 compile; host awk performs the M1 code/data
##           section split; Apple sed edits mescc output; M1 (step
##           12), hex2 (step 13), macho-patcher (step 06) assemble
##           and link the smoke binary; Apple cat, dd, chmod,
##           install, cp, test.
## Inputs:   target/mes-source lib/{mes,stdlib,string,darwin}/...
##           C sources (step 15),
##           target/share/mescc-trivial/mescc.scm (step 20),
##           target/nyacc (step 19),
##           sources/mescc-libc-fixtures/libc-mini-puts-smoke.c
##           (committed fixture calling puts("libc-mini")),
##           mes lib M1 defs + crt1-libc.M1, and the stage0 lowdata
##           MACHO template.
## Outputs:  target/share/libc-mini/{libc-mini.M1,puts-smoke.M1}.
## Verifies: each compile must produce a non-empty .M1; the linked
##           puts-smoke binary runs and its stdout must equal
##           "libc-mini" — mescc-compiled code, the split archive,
##           and the crt1/link recipe all work.
## Trust:    host awk transforms assembler text here (the code/data
##           split) — part of the documented "host awk for the early
##           M1 code/data splits" boundary in build.sh.  Host sed
##           deletes stray lines from mescc output.  All C
##           compilation, assembly, and linking is chain-built.
set -eu

mes_source="$TARGET/mes-source"
nyacc_dir="$TARGET/nyacc/share/nyacc-1.09.1"
work="$TARGET/work/libc-mini"
rm -rf "$work"
mkdir -p "$work/m1"
cd "$work"

mesLoadPath="$mes_source/module:$mes_source/mes/module:$nyacc_dir/module"

## mescc invocation wrapper; env as in step 20.
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

## Compile one C file to .M1 (-S: compile stage only).  The sed pass
## deletes lines consisting of a single '<' from the mescc output;
## the result is made read-only to catch accidental rewrites.
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

## Compile 10 libc source files
compile_m1 "$mes_source/lib/mes/__init_io.c" m1/__init_io.M1
compile_m1 "$mes_source/lib/mes/eputs.c" m1/eputs.M1
compile_m1 "$mes_source/lib/mes/oputs.c" m1/oputs.M1
compile_m1 "$mes_source/lib/mes/globals.c" m1/globals.M1
compile_m1 "$mes_source/lib/stdlib/exit.c" m1/exit.M1
compile_m1 "$mes_source/lib/darwin/x86_64-mes-mescc/_exit.c" m1/_exit.M1
compile_m1 "$mes_source/lib/darwin/x86_64-mes-mescc/_write.c" m1/_write.M1
compile_m1 "$mes_source/lib/stdlib/puts.c" m1/puts.M1
compile_m1 "$mes_source/lib/string/strlen.c" m1/strlen.M1
compile_m1 "$mes_source/lib/mes/write.c" m1/write.M1

cp "$SOURCES/mescc-libc-fixtures/libc-mini-puts-smoke.c" puts-smoke.c
compile_m1 puts-smoke.c puts-smoke.M1

## Split each .M1 into code/data sections and concatenate into a single
## libc-mini.M1 archive.  hex2 lays the image out as code up to the
## :ELF_data label, then data; each mescc .M1 carries its own
## code→data transition, so concatenating whole files would scatter
## data labels through the code region.  The awk passes gather every
## file's code first and its data second, and the archive gets one
## shared :ELF_data/:HEX2_data boundary.  Two special cases:
## globals.M1 is all data; exit.M1's data starts at its
## :__call_at_exit global (that label line is kept in the data half).
: > libc-mini.code.M1
: > libc-mini.data.M1
for file in m1/*.M1; do
    if [ "$(basename "$file")" = "globals.M1" ]; then
        cat "$file" >> libc-mini.data.M1
        continue
    fi
    split_label='^:ELF_data$'
    if [ "$(basename "$file")" = "exit.M1" ]; then
        split_label='^:__call_at_exit$'
    fi
    ## Code half: lines before the split label; marker lines dropped.
    awk '
        split_re != "" && $0 ~ split_re { data = 1; next }
        /^:ELF_data$/ { data = 1; next }
        /^:HEX2_data$/ { next }
        data != 1 { print }
    ' split_re="$split_label" "$file" >> libc-mini.code.M1
    ## Data half: lines from the split label on; a custom split label
    ## is a real symbol, so it is printed; markers are dropped.
    awk '
        split_re != "" && $0 ~ split_re { data = 1; print; next }
        /^:ELF_data$/ { data = 1; next }
        /^:HEX2_data$/ { next }
        data == 1 { print }
    ' split_re="$split_label" "$file" >> libc-mini.data.M1
done
{
    cat libc-mini.code.M1
    echo ':ELF_data'
    echo ':HEX2_data'
    cat libc-mini.data.M1
} > libc-mini.M1

## Build puts-smoke combined image for verification: same split for
## the fixture object, then libc code + fixture code, one boundary,
## libc data + fixture data.
awk '
    /^:ELF_data$/ { data = 1; next }
    /^:HEX2_data$/ { next }
    data != 1 { print }
' puts-smoke.M1 > puts-smoke.code.M1
awk '
    /^:ELF_data$/ { data = 1; next }
    /^:HEX2_data$/ { next }
    data == 1 { print }
' puts-smoke.M1 > puts-smoke.data.M1
{
    cat libc-mini.code.M1
    cat puts-smoke.code.M1
    echo ':ELF_data'
    echo ':HEX2_data'
    cat libc-mini.data.M1
    cat puts-smoke.data.M1
} > puts-smoke-combined.M1

## Link recipe as in step 18, with the mescc crt1-libc (calls
## __init_io/main/exit) in place of the mes-m2 crt1.
M1 \
  --architecture amd64 \
  --little-endian \
  -f "$mes_source/lib/m2/x86_64/x86_64_defs.M1" \
  -f "$mes_source/lib/x86_64-mes/x86_64.M1" \
  -f "$mes_source/lib/darwin/x86_64-mes-mescc/crt1-libc.M1" \
  -f puts-smoke-combined.M1 \
  -o puts-smoke.hex2

## --base-address 0x1000000 as for the mes image (step 18).
hex2 \
  --architecture amd64 \
  --little-endian \
  --base-address 0x1000000 \
  -f "$SOURCES/stage0-posix/M2libc/amd64/MACHO-amd64-lowdata.hex2" \
  -f puts-smoke.hex2 \
  -o puts-smoke

macho-patcher m2-segments puts-smoke.hex2 puts-smoke

## Pad to the 0x2800000 __LINKEDIT file offset (see step 05).
dd if=/dev/zero of=puts-smoke bs=1 count=1 seek=41943039 conv=notrunc 2>/dev/null || true
chmod +x puts-smoke

## Smoke test: run the linked binary; stdout must be exactly the
## string the fixture puts().
./puts-smoke > puts-smoke.stdout 2> puts-smoke.stderr
test "$(cat puts-smoke.stdout)" = "libc-mini"

## Stage libc-mini.M1 for downstream phases.
install -d "$TARGET/share/libc-mini"
cp libc-mini.M1 puts-smoke.M1 "$TARGET/share/libc-mini/"
