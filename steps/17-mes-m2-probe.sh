#!/bin/sh
## 16-mes-m2-probe — compile mes.M1 from mes C sources via M2-Planet.
##
## Mirrors mes/m2-compile.nix: takes mes's upstream kaem.run, sed-
## rewrites Linux paths to Darwin paths, runs it (early-stops at
## the first .M1 produced) under sh with M2 on PATH.
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

if [ "$status" -ne 99 ]; then
    echo "mes-m2-only.sh expected exit 99 but got $status; check mes-m2.stderr" >&2
    tail -20 mes-m2.stderr >&2
    exit 1
fi

test -s m2/mes.M1
install -d "$TARGET/share/mes-m2-probe"
cp m2/mes.M1 "$TARGET/share/mes-m2-probe/mes.M1"
