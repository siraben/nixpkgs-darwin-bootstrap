#!/bin/sh
## 17-mes-m2-probe — compile mes.M1 from the mes C sources via
## M2-Planet.  Mirrors mes/m2-compile.nix.
##
## mes ships kaem.run, its upstream bootstrap build script, whose
## first command runs M2-Planet over the mes interpreter's C sources
## to produce m2/mes.M1.  This step rewrites the Linux libc paths in
## that script to the Darwin layer staged by step 15, runs it under
## /bin/sh with target/bin on PATH, and stops it right after mes.M1
## is produced.  Step 18 links the resulting mes.M1 into the mes-m2
## binary.
##
## Runs:     Apple sed and awk rewrite kaem.run (host text edits of a
##           build script); Apple /bin/sh executes the rewritten
##           script, which invokes M2-Planet (step 16).
## Inputs:   target/mes-source (step 15): kaem.run plus the C sources
##           and Darwin lib/ files it lists.
## Outputs:  target/share/mes-m2-probe/mes.M1.
## Verifies: the run must exit with the injected status 99 (see
##           below) and mes.M1 must be non-empty.
## Trust:    host sed/awk edit the build script (path substitutions
##           and the early stop); translation is done by chain-built
##           M2-Planet.  /bin/sh orchestrates.
set -eu

mes_source="$TARGET/mes-source"
if [ ! -d "$mes_source" ]; then
    echo "missing $mes_source; run 15-mes-source.sh first" >&2
    exit 1
fi

work="$TARGET/work/mes-m2-probe"
rm -rf "$work"
mkdir -p "$work"
cd "$work"

## Rewrite Linux paths to Darwin and early-stop after mes.M1.
## sed swaps each lib/linux (and lib/m2/execve.c) reference for the
## lib/darwin file with the same role.  awk appends `exit 99` right
## after the line ending the M2-Planet command (`-o m2/mes.M1`), so
## the script stops before its blood-elf/M1/hex2 ELF link steps;
## status 99 marks the intentional stop, distinct from any failure.
sed \
  -e 's|lib/linux/${mes_cpu}-mes-m2/crt1.c|lib/darwin/${mes_cpu}-mes-m2/crt1.c|g' \
  -e 's|lib/linux/${mes_cpu}-mes-m2/_exit.c|lib/darwin/${mes_cpu}-mes-m2/_exit.c|g' \
  -e 's|lib/linux/${mes_cpu}-mes-m2/_write.c|lib/darwin/${mes_cpu}-mes-m2/_write.c|g' \
  -e 's|include/linux/${mes_cpu}/syscall.h|include/darwin/${mes_cpu}/syscall.h|g' \
  -e 's|lib/linux/${mes_cpu}-mes-m2/syscall.c|lib/darwin/${mes_cpu}-mes-m2/syscall.c|g' \
  -e 's|lib/linux/brk.c|lib/darwin/brk.c|g' \
  -e 's|lib/linux/malloc.c|lib/darwin/malloc.c|g' \
  -e 's|lib/linux/read.c|lib/darwin/read.c|g' \
  -e 's|lib/linux/_open3.c|lib/darwin/_open3.c|g' \
  -e 's|lib/linux/open.c|lib/darwin/open.c|g' \
  -e 's|lib/linux/access.c|lib/darwin/access.c|g' \
  -e 's|lib/linux/chmod.c|lib/darwin/chmod.c|g' \
  -e 's|lib/linux/ioctl3.c|lib/darwin/ioctl3.c|g' \
  -e 's|lib/linux/fork.c|lib/darwin/fork.c|g' \
  -e 's|lib/m2/execve.c|lib/darwin/execve.c|g' \
  -e 's|lib/linux/wait4.c|lib/darwin/wait4.c|g' \
  -e 's|lib/linux/waitpid.c|lib/darwin/waitpid.c|g' \
  -e 's|lib/linux/gettimeofday.c|lib/darwin/gettimeofday.c|g' \
  -e 's|lib/linux/clock_gettime.c|lib/darwin/clock_gettime.c|g' \
  -e 's|lib/linux/_getcwd.c|lib/darwin/_getcwd.c|g' \
  -e 's|lib/linux/dup.c|lib/darwin/dup.c|g' \
  -e 's|lib/linux/dup2.c|lib/darwin/dup2.c|g' \
  -e 's|lib/linux/uname.c|lib/darwin/uname.c|g' \
  -e 's|lib/linux/unlink.c|lib/darwin/unlink.c|g' \
  "$mes_source/kaem.run" \
  | awk '{ print } /-o m2\/mes\.M1/ { print "exit 99"; exit }' \
  > mes-m2-only.sh

## Env consumed by kaem.run: srcdest prefixes every source path;
## cc_cpu/mes_cpu/stage0_cpu select the amd64/x86_64 file sets;
## blood_elf_flag is referenced by a command past the early stop.
set +e
PATH="$TARGET/bin:/usr/bin:/bin" \
  srcdest="$mes_source/" \
  cc_cpu=x86_64 \
  mes_cpu=x86_64 \
  stage0_cpu=amd64 \
  blood_elf_flag=--64 \
  /bin/sh mes-m2-only.sh > mes-m2.stdout 2> mes-m2.stderr
status="$?"
set -e

## 99 is the injected marker: the script reached the point right
## after M2-Planet wrote mes.M1.  Any other status is a real failure.
if [ "$status" -ne 99 ]; then
    echo "mes-m2-only.sh expected exit 99 but got $status; check mes-m2.stderr" >&2
    tail -20 mes-m2.stderr >&2
    exit 1
fi

test -s m2/mes.M1
install -d "$TARGET/share/mes-m2-probe"
cp m2/mes.M1 "$TARGET/share/mes-m2-probe/mes.M1"
