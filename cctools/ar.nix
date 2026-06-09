{
  cctools,
  phase47-gcc-latest-strict-bootstrap,
  runCommand,
  ...
}:
## Chain-build cctools `ar` + `ranlib` from source with the from-seed gcc-15
## (phase47 strict). gcc-15 + the apple-sdk headers it carries compile cctools
## natively (the chain tcc can't — it lacks #import/__has_include and trips on
## Apple's arch headers). The resulting binaries are chain-COMPILED; they are
## assembled/linked by the host cctools as/ld64, the same irreducible boundary
## as gcc-4.6/10/15 themselves. Used only downstream of gcc-15 (gnu-hello),
## since ar is also needed by the earlier tinycc/gcc-4.6 phases that predate any
## capable chain compiler.
runCommand "phase39b-cctools-ar" { } ''
  src=${cctools.src}
  mkdir -p build "$out/bin" "$out/share/darwin-bootstrap"
  cd build

  export PATH="${phase47-gcc-latest-strict-bootstrap}/bin:${cctools}/bin:/usr/bin:/bin:/usr/sbin:/sbin"
  export CC="${phase47-gcc-latest-strict-bootstrap}/bin/gcc"
  export GCC_MODERN_WRAPPER_HOST_SHORTCUTS=0
  ## -std=gnu11: gcc-15 defaults to gnu23 where `bool` is a keyword, breaking
  ## cctools' `enum bool`. -D__private_extern__: Apple visibility keyword gcc lacks.
  ## -D_DARWIN_C_SOURCE exposes BSD libc (reallocf etc.); the -Wno-error flags
  ## let old cctools C (stray implicit decls) build on gcc-15, which promotes
  ## these to hard errors by default.
  ## Force-include a tiny BSD-types compat header: some cctools sources use
  ## u_char/u_int32_t etc. without including the header that declares them.
  cat > bsd-compat.h <<'BSDH'
#include <sys/types.h>
#include <sys/param.h>
#include <sys/mman.h>
#include <stdint.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <errno.h>
#include <sys/stat.h>
#include <sys/file.h>
#include <sys/wait.h>
#include <sys/time.h>
/* libtool.c uses these without a declaration on this SDK; an implicit int
   decl truncates their pointer args/returns and crashes ranlib at runtime. */
int mkstemp(char *);
int fchmod(int, unsigned short);
int asprintf(char **, const char *, ...);
#ifndef MIN
#define MIN(a, b) ((a) < (b) ? (a) : (b))
#endif
#ifndef MAX
#define MAX(a, b) ((a) > (b) ? (a) : (b))
#endif
#ifndef WEXITSTATUS
#define WEXITSTATUS(x) (((x) >> 8) & 0xff)
#define WTERMSIG(x) ((x) & 0x7f)
#define WIFEXITED(x) (((x) & 0x7f) == 0)
#define WIFSIGNALED(x) (((x) & 0x7f) != 0 && ((x) & 0x7f) != 0x7f)
#define WIFSTOPPED(x) (((x) & 0xff) == 0x7f)
#define WSTOPSIG(x) (((x) >> 8) & 0xff)
#endif
typedef unsigned char u_char;
typedef unsigned short u_short;
typedef unsigned int u_int;
typedef unsigned long u_long;
typedef unsigned char u_int8_t;
typedef unsigned short u_int16_t;
typedef unsigned int u_int32_t;
typedef unsigned long long u_int64_t;
extern int optind, opterr, optopt;
extern char *optarg;
#ifndef STDERR_FILENO
#define STDIN_FILENO 0
#define STDOUT_FILENO 1
#define STDERR_FILENO 2
#endif
#ifndef PATH_MAX
#define PATH_MAX 1024
#endif
#ifndef MAXPATHLEN
#define MAXPATHLEN 1024
#endif
#ifndef NGROUPS
#define NGROUPS 16
#endif
#ifndef MAXHOSTNAMELEN
#define MAXHOSTNAMELEN 256
#endif
#ifndef MAXNAMLEN
#define MAXNAMLEN 255
#endif
#ifndef MAP_FILE
#define MAP_FILE 0
#endif
#ifndef O_FSYNC
#define O_FSYNC 0x0080
#endif
#ifndef O_SHLOCK
#define O_SHLOCK 0x0010
#endif
#ifndef O_EXLOCK
#define O_EXLOCK 0x0020
#endif
#ifndef O_ACCMODE
#define O_ACCMODE 0x0003
#endif
#ifndef DEFFILEMODE
#define DEFFILEMODE 0666
#endif
#ifndef LOCK_SH
#define LOCK_SH 1
#define LOCK_EX 2
#define LOCK_NB 4
#define LOCK_UN 8
#endif
#ifndef ESTALE
#define ESTALE 70
#endif
#ifndef EBADRPC
#define EBADRPC 72
#endif
#ifndef EFTYPE
#define EFTYPE 79
#endif
#ifndef L_SET
#define L_SET 0
#define L_INCR 1
#define L_XTND 2
#endif
#ifndef MAP_RESILIENT_CODESIGN
#define MAP_RESILIENT_CODESIGN 0x2000
#endif
#ifndef MAP_RESILIENT_MEDIA
#define MAP_RESILIENT_MEDIA 0x4000
#endif
#ifndef CPU_TYPE_RISCV32
#define CPU_TYPE_RISCV32 ((cpu_type_t)24)
#endif
#ifndef CPU_TYPE_ARM64_32
#define CPU_TYPE_ARM64_32 ((cpu_type_t)0x0100000c)
#endif
BSDH
  CFLAGS="-O2 -g0 -std=gnu11 -D_DARWIN_C_SOURCE -D__private_extern__=extern -D__builtin_available(...)=1 -include $PWD/bsd-compat.h -Wno-error=implicit-function-declaration -Wno-error=int-conversion -Wno-error=implicit-int -I$src/include -I$src/include/stuff -DEFI_SUPPORT"

  ## diagnostics_log_args() runs open_memstream()/strdup() even when diagnostics
  ## are DISABLED (CC_LOG_DIAGNOSTICS unset, our case); that path has UB that
  ## crashes ranlib under gcc-15. Skip the work when disabled (early return).
  awk '
    /void diagnostics_log_args\(/ { f = 1 }
    f && /^\{/ { print; print "    if (diagnostics_state != 1) return;"; f = 0; next }
    { print }
  ' "$src"/libstuff/diagnostics.c > diagnostics_patched.c

  ## libstuff.a + libmacho.a (host ar is a build tool here; the OUTPUT ar/ranlib
  ## are the chain-compiled artifacts).
  for f in "$src"/libstuff/*.c; do
    ## lto.c/llvm.c need LLVM headers (llvm-c/lto.h); ar/ranlib don't do LTO and
    ## (without -DLTO_SUPPORT) never reference these symbols, so skip them.
    case "$(basename "$f")" in lto.c | llvm.c) continue ;; esac
    cf="$f"
    [ "$(basename "$f")" = diagnostics.c ] && cf="$PWD/diagnostics_patched.c"
    "$CC" $CFLAGS -c "$cf" -o "ls_$(basename "$f" .c).o" \
      > "ls_$(basename "$f" .c).log" 2>&1
  done
  ${cctools}/bin/ar rcs libstuff.a ls_*.o

  for f in "$src"/libmacho/*.c; do
    "$CC" $CFLAGS -c "$f" -o "lm_$(basename "$f" .c).o" \
      > "lm_$(basename "$f" .c).log" 2>&1
  done
  ${cctools}/bin/ar rcs libmacho.a lm_*.o

  ## ar
  for f in "$src"/ar/*.c; do
    "$CC" $CFLAGS -c "$f" -o "ar_$(basename "$f" .c).o" \
      > "ar_$(basename "$f" .c).log" 2>&1
  done
  "$CC" $CFLAGS -o ar ar_*.o libstuff.a libmacho.a

  ## ranlib == libtool invoked as ranlib (cctools convention).
  "$CC" $CFLAGS -c "$src"/misc/libtool.c -o libtool.o > libtool.log 2>&1
  "$CC" $CFLAGS -o libtool libtool.o libstuff.a libmacho.a

  ## Smoke test. NB: cctools `ar rc` auto-execs a sibling `ranlib`, which fails
  ## inside cctools `execute()` here; `ar rcS` (no auto-ranlib) + a separate
  ## `ranlib` both work, so consumers (gnu-hello) use ARFLAGS=rcS + RANLIB.
  ln -s libtool ranlib
  printf 'int chain_ar_probe(void){ return 42; }\n' > probe.c
  "$CC" -O2 -g0 -c probe.c -o probe.o
  ./ar rcS probe.a probe.o
  ./ar t probe.a | grep -qx probe.o
  ./ranlib probe.a
  ./ar t probe.a | grep -qx probe.o

  install -Dm755 ar "$out/bin/ar"
  install -Dm755 libtool "$out/bin/libtool"
  ln -s libtool "$out/bin/ranlib"
  cp probe.a "$out/share/darwin-bootstrap/" 2>/dev/null || true
''
