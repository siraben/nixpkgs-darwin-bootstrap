#!/bin/sh
# Explicitly link gcc-10's `cc1` from its already-compiled objects.
#
# Why this is a separate script and not just `make cc1`:
#   1. The g++ wrapper (gcc46-cxx) strips -L/-l (it forwards only -f*/source/-o
#      tokens to cc1plus), so gcc-10's math libs (-lmpc -lmpfr -lgmp -lz) are
#      never seen by a plain `make cc1`.  We pass the full -L paths + -l flags
#      directly here.
#   2. `make cc1` re-archives libbackend.a (ar embeds mtimes) -> the resolve
#      cache misses and the whole archive re-resolves (~40 min).  Linking the
#      pinned object list directly keeps the warm resolve cache (~6 min).
#
# The object list mirrors gcc/Makefile's $(OBJS) for the C front-end cc1 as of
# gcc-10.4.0.  If you bump gcc, regenerate it from `make cc1 V=1` (the final
# g++ link line) rather than editing by hand.
set -u

ROOT="${ROOT:-$(cd -- "$(dirname -- "$0")/.." && pwd)}"
. "$ROOT/scripts/gcc10-env.sh"
B="$GCC10_BUILD"

cd "$B/gcc"
rm -f cc1
"$CXX" -O0 -std=gnu++0x -mno-sse3 -fpermissive $GCC10_GGC \
  -DIN_GCC -fno-exceptions -fno-rtti -fasynchronous-unwind-tables -DHAVE_CONFIG_H -o cc1 \
  c/c-lang.o c-family/stub-objc.o attribs.o c/c-errors.o c/c-decl.o c/c-typeck.o c/c-convert.o \
  c/c-aux-info.o c/c-objc-common.o c/c-parser.o c/c-fold.o c/gimple-parser.o c-family/c-common.o \
  c-family/c-cppbuiltin.o c-family/c-dump.o c-family/c-format.o c-family/c-gimplify.o \
  c-family/c-indentation.o c-family/c-lex.o c-family/c-omp.o c-family/c-opts.o c-family/c-pch.o \
  c-family/c-ppoutput.o c-family/c-pragma.o c-family/c-pretty-print.o c-family/c-semantics.o \
  c-family/c-ada-spec.o c-family/c-ubsan.o c-family/known-headers.o c-family/c-attribs.o \
  c-family/c-warn.o c-family/c-spellcheck.o i386-c.o darwin-c.o cc1-checksum.o \
  libbackend.a main.o libcommon-target.a libcommon.a ../libcpp/libcpp.a ../libdecnumber/libdecnumber.a \
  libcommon.a ../libcpp/libcpp.a ../libbacktrace/.libs/libbacktrace.a ../libiberty/libiberty.a \
  ../libdecnumber/libdecnumber.a \
  -L"$B"/./gmp/.libs -L"$B"/./mpfr/src/.libs -L"$B"/./mpc/src/.libs -lmpc -lmpfr -lgmp -L./../zlib -lz
echo "LINKCC1_EXIT=$?"
