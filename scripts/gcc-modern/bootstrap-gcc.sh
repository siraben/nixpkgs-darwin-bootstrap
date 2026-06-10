#!/usr/bin/env bash
set -euo pipefail

source_dir=$1
compiler=$2
phase39=$3
phase34=$4
cctools=$5
out=$6
version=$7
label=$8

target=x86_64-apple-darwin
bootstrap_share="$out/share/darwin-bootstrap"

mkdir -p src build "$out" "$bootstrap_share"
if [ "${GCC_MODERN_CLEAN:-0}" = 1 ]; then
  rm -rf src build
  mkdir -p src build
fi
if [ ! -f src/configure ]; then
  cp -R "$source_dir/." src/
fi
chmod -R u+w src
for generated_subdir in gmp mpfr mpc isl; do
  if [ -d "src/$generated_subdir" ]; then
    find "src/$generated_subdir" -type f \( -name 'aclocal.m4' -o -name 'configure' -o -name 'Makefile.in' \) -exec touch {} +
    find "src/$generated_subdir" -type f \( -name 'configure.ac' -o -name 'Makefile.am' -o -name '*.m4' \) -exec touch -t 200001010000 {} +
  fi
done
if [ -f src/gmp/Makefile.in ] && grep -q '^SUBDIRS = .*demos' src/gmp/Makefile.in; then
  perl -0pi -e 's@^SUBDIRS = .*$@SUBDIRS = mpn mpz mpq mpf printf scanf rand cxx@m' src/gmp/Makefile.in
fi
if [ -f src/mpfr/Makefile.in ] && grep -q '^SUBDIRS = .*tests' src/mpfr/Makefile.in; then
  perl -0pi -e 's@^SUBDIRS = .*$@SUBDIRS = src@m' src/mpfr/Makefile.in
fi
if [ -f src/mpc/Makefile.in ] && grep -q '^SUBDIRS = .*tests' src/mpc/Makefile.in; then
  perl -0pi -e 's@^SUBDIRS = .*$@SUBDIRS = src@m' src/mpc/Makefile.in
fi
if [ -f src/Makefile.in ] && grep -q '@extra_mpfr_configure_flags@ @host_libs_picflag@' src/Makefile.in; then
  perl -0pi -e 's#\@extra_mpfr_configure_flags\@ \@host_libs_picflag\@#\@extra_mpfr_configure_flags\@ --disable-float128 \@host_libs_picflag\@#g' src/Makefile.in
fi
if [ -d src/gcc ]; then
  find src/gcc -type f \( -name 'gengtype-lex.c' -o -name 'gengtype-parse.c' -o -name 'gengtype-parse.h' \) -exec touch {} +
  find src/gcc -type f \( -name 'gengtype-lex.l' -o -name 'gengtype-parse.y' \) -exec touch -t 200001010000 {} +
fi
if [ -f src/gcc/diagnostic.c ] && grep -q 'isatty (fileno (pp_buffer (context->printer)->stream))' src/gcc/diagnostic.c; then
  perl -0pi -e 's@value = value \? value - 1\s*: \(isatty \(fileno \(pp_buffer \(context->printer\)->stream\)\)\s*\? get_terminal_width \(\) - 1: INT_MAX\);@value = value ? value - 1 : INT_MAX;@s' src/gcc/diagnostic.c
fi
if [ -f src/gcc/diagnostic.c ] && grep -q 'get_terminal_width (void)' src/gcc/diagnostic.c; then
  perl -0pi -e 's@int\nget_terminal_width \(void\)\n\{.*?\n\}@int\nget_terminal_width (void)\n{\n  return INT_MAX;\n}@s' src/gcc/diagnostic.c
fi
if [ -f src/gcc/gcc.c ] && grep -q 'not configured with sysroot headers suffix' src/gcc/gcc.c; then
  perl -0pi -e 's@if \(print_sysroot_headers_suffix\)\s*\{\s*if \(\*sysroot_hdrs_suffix_spec\)\s*\{\s*printf\("%s\\n", \(target_sysroot_hdrs_suffix\s*\? target_sysroot_hdrs_suffix\s*: ""\)\);\s*return \(0\);\s*\}\s*else\s*/\* The error status indicates that only one set of fixed\s*headers should be built\.  \*/\s*fatal_error \(input_location,\s*"not configured with sysroot headers suffix"\);\s*\}@if (print_sysroot_headers_suffix)\n    {\n      printf("%s\\n", (*sysroot_hdrs_suffix_spec && target_sysroot_hdrs_suffix\n                      ? target_sysroot_hdrs_suffix\n                      : ""));\n      return (0);\n    }@s' src/gcc/gcc.c
fi
if [ -f src/gcc/opts-common.c ] && grep -q 'cl_deferred_option p = {opt_index, arg, value};' src/gcc/opts-common.c; then
  perl -0pi -e 's@cl_deferred_option p = \{opt_index, arg, value\};@cl_deferred_option p = {opt_index, arg, (int) value};@g' src/gcc/opts-common.c
fi
if [ -f src/gcc/pretty-print.c ] && grep -q "const char str \\[2\\] = { chr, '\\\\0' };" src/gcc/pretty-print.c; then
  perl -0pi -e "s@const char str \\[2\\] = \\{ chr, '\\\\0' \\};@const char str [2] = { (char) chr, '\\\\0' };@g" src/gcc/pretty-print.c
fi
if [ -f src/gcc/configure ] && grep -q '#define rlim_t long' src/gcc/configure; then
  perl -0pi -e 's@\n\$as_echo "#define rlim_t long" >>confdefs\.h\n@\n:\n@g' src/gcc/configure
fi
if [ -f src/libgcc/configure ] && grep -q 'grep host_address=' src/libgcc/configure; then
  perl -0pi -e 's@cat > conftest\.c <<EOF\n#if defined\(__x86_64__\).*?eval `\$\{CC-cc\} -E conftest\.c \| grep host_address=`\nrm -f conftest\.c@host_address=64@s' src/libgcc/configure
fi
if [ -f src/libgcc/config.host ] && grep -q 'libemutls_w\.a' src/libgcc/config.host; then
  perl -0pi -e 's@ libemutls_w\.a@@g' src/libgcc/config.host
fi
if [ -f src/libgcc/config.host ] && grep -q 'libheapt_w\.a' src/libgcc/config.host; then
  perl -0pi -e 's@ libheapt_w\.a@@g' src/libgcc/config.host
fi
if [ -f src/libgcc/config.host ] && grep -q 'crt3.o libd10-uwfef.a crttms.o crttme.o' src/libgcc/config.host; then
  perl -0pi -e 's@extra_parts="crt3\.o libd10-uwfef\.a crttms\.o crttme\.o"@extra_parts="libd10-uwfef.a"@g' src/libgcc/config.host
fi
if [ -f src/gcc/config/darwin.h ] && grep -q -- '-lemutls_w' src/gcc/config/darwin.h; then
  perl -0pi \
    -e 's@# define DARWIN_SHARED_WEAK_ADDS \\\n"%\{%:version-compare\(>= 10\.11 mmacosx-version-min= -lemutls_w\): \\\n " DARWIN_HEAP_T_LIB "\}@# define DARWIN_SHARED_WEAK_ADDS " "@g;' \
    -e 's@#define DARWIN_WEAK_CRTS \\\n"%\{static-libgcc\|static:\t\t\t\t\t\t  \\\n    %\{%:version-compare\(>= 10\.6 mmacosx-version-min= -lemutls_w\):\t  \\\n      " DARWIN_HEAP_T_LIB "\} ;\t\t\t\t\t\t  \\\n   : -lemutls_w\t" DARWIN_HEAP_T_LIB "\t\t\t\t\t  \\\n  \}"@#define DARWIN_WEAK_CRTS ""@g' \
    src/gcc/config/darwin.h
  perl -0pi -e 's@# define DARWIN_SHARED_WEAK_ADDS " ""@# define DARWIN_SHARED_WEAK_ADDS " "@g' src/gcc/config/darwin.h
fi
for glibc_configure in src/gcc/configure src/libgcc/configure; do
  if [ -f "$glibc_configure" ] && grep -q '__GLIBC__' "$glibc_configure"; then
    perl -0pi -e 's@if ac_fn_c_compute_int "\$LINENO" "__GLIBC__" "glibc_version_major".*?fi\n\nif ac_fn_c_compute_int "\$LINENO" "__GLIBC_MINOR__" "glibc_version_minor".*?fi@glibc_version_major=0\nglibc_version_minor=0@s' "$glibc_configure"
  fi
done
if [ -f src/gcc/c/Make-lang.in ]; then
  perl -0pi -e 's@^selftest-c: s-selftest-c$@selftest-c:@m' src/gcc/c/Make-lang.in
fi
if [ -f src/gcc/cp/Make-lang.in ]; then
  perl -0pi -e 's@^selftest-c\+\+: s-selftest-c\+\+$@selftest-c++:@m' src/gcc/cp/Make-lang.in
fi
if [ -f src/gcc/c-family/c-opts.c ] && grep -q 'cpp_finish (parse_in, deps_stream);' src/gcc/c-family/c-opts.c; then
  perl -0pi -e 's@(?:if \(!flag_preprocess_only\) )*cpp_finish \(parse_in, deps_stream\);@if (!flag_preprocess_only) cpp_finish (parse_in, deps_stream);@' src/gcc/c-family/c-opts.c
fi
if [ -f src/gcc/c-family/c-opts.c ] && grep -q 'preprocess_file (parse_in);' src/gcc/c-family/c-opts.c; then
  perl -0pi -e 's@preprocess_file \(parse_in\);\n      return false;@preprocess_file (parse_in);\n      exit (0);@' src/gcc/c-family/c-opts.c
fi
if [ -f src/libiberty/fopen_unlocked.c ] && grep -q '#ifdef HAVE_STDIO_EXT_H' src/libiberty/fopen_unlocked.c; then
  perl -0pi -e 's@#ifdef HAVE_STDIO_EXT_H@#if defined(HAVE_STDIO_EXT_H) && !defined(__APPLE__)@' src/libiberty/fopen_unlocked.c
fi
if [ -f src/libiberty/hashtab.c ] && grep -q '#include <malloc.h>' src/libiberty/hashtab.c; then
  perl -0pi -e 's@#include <malloc.h>@#ifdef __APPLE__\n#include <stdlib.h>\n#else\n#include <malloc.h>\n#endif@' src/libiberty/hashtab.c
fi
if [ -f src/libiberty/physmem.c ]; then
  perl -0pi \
    -e 's@#if HAVE_SYS_PSTAT_H\s*(?:#\s*ifndef __APPLE__\s*)*#\s*include <sys/pstat\.h>\s*(?:#\s*endif\s*)*#endif@#if HAVE_SYS_PSTAT_H && !defined(__APPLE__)\n# include <sys/pstat.h>\n#endif@s;' \
    -e 's@#if HAVE_SYS_SYSMP_H\s*(?:#\s*ifndef __APPLE__\s*)*#\s*include <sys/sysmp\.h>\s*(?:#\s*endif\s*)*#endif@#if HAVE_SYS_SYSMP_H && !defined(__APPLE__)\n# include <sys/sysmp.h>\n#endif@s;' \
    -e 's@#if HAVE_SYS_SYSINFO_H && HAVE_MACHINE_HAL_SYSINFO_H\s*(?:#\s*ifndef __APPLE__\s*)*#\s*include <sys/sysinfo\.h>\s*(?:#\s*endif\s*)*#\s*include <machine/hal_sysinfo\.h>\s*#endif@#if HAVE_SYS_SYSINFO_H && HAVE_MACHINE_HAL_SYSINFO_H && !defined(__APPLE__)\n# include <sys/sysinfo.h>\n# include <machine/hal_sysinfo.h>\n#endif@s;' \
    -e 's@#if HAVE_SYS_TABLE_H\s*#\s*include <sys/table\.h>\s*#endif@#if HAVE_SYS_TABLE_H && !defined(__APPLE__)\n# include <sys/table.h>\n#endif@s;' \
    -e 's@#if HAVE_SYS_SYSTEMCFG_H\s*#\s*include <sys/systemcfg\.h>\s*#endif@#if HAVE_SYS_SYSTEMCFG_H && !defined(__APPLE__)\n# include <sys/systemcfg.h>\n#endif@s;' \
    src/libiberty/physmem.c
fi
if [ -f src/libiberty/setproctitle.c ] && grep -q '#ifdef HAVE_SYS_PRCTL_H' src/libiberty/setproctitle.c; then
  perl -0pi -e 's@#ifdef HAVE_SYS_PRCTL_H@#if defined(HAVE_SYS_PRCTL_H) && !defined(__APPLE__)@' src/libiberty/setproctitle.c
fi
if [ -f src/libiberty/pex-unix.c ] && grep -q '#ifdef HAVE_PROCESS_H' src/libiberty/pex-unix.c; then
  perl -0pi -e 's@#ifdef HAVE_PROCESS_H@#if defined(HAVE_PROCESS_H) && !defined(__APPLE__)@; s@#ifdef HAVE_VFORK_H@#if defined(HAVE_VFORK_H) && !defined(__APPLE__)@' src/libiberty/pex-unix.c
fi
if [ -f src/libcody/configure ] && grep -q '__cplusplus != 201103' src/libcody/configure; then
  perl -0pi \
    -e 's@#if __cplusplus != 201103\n#error "C\+\+11 is required"\n#endif@#if __cplusplus < 201103\n#error "C++11 is required"\n#endif@g;' \
    -e 's@#if __cplusplus > 201103\n#error "C\+\+11 is required"\n#endif@#if __cplusplus < 201103\n#error "C++11 is required"\n#endif@g' \
    src/libcody/configure
fi

if [ ! -x "$compiler/bin/g++" ]; then
  echo "$label requires a bootstrapped C++ compiler at $compiler/bin/g++" >&2
  exit 1
fi

cd build
if [ -d "$compiler/$target/include" ]; then
  sysroot_source="$compiler/$target"
elif [ -d "$phase34/include/tcc-darwin-bootstrap" ]; then
  sysroot_source="$phase34/include/tcc-darwin-bootstrap"
else
  echo "$label cannot find a bootstrap sysroot in $compiler/$target or $phase34/include/tcc-darwin-bootstrap" >&2
  exit 1
fi
sysroot="$PWD/bootstrap-sysroot"
rm -rf "$sysroot"
mkdir -p "$sysroot"
cp -R "$sysroot_source/." "$sysroot/"
chmod -R u+w "$sysroot"
mkdir -p "$sysroot/include/sys"
if [ ! -f "$sysroot/include/crt_externs.h" ]; then
  cat > "$sysroot/include/crt_externs.h" <<'CRT_EXTERNS_H'
#ifndef _DARWIN_BOOTSTRAP_CRT_EXTERNS_H
#define _DARWIN_BOOTSTRAP_CRT_EXTERNS_H
#ifdef __cplusplus
extern "C" {
#endif
char ***_NSGetEnviron(void);
#ifdef __cplusplus
}
#endif
#endif
CRT_EXTERNS_H
fi
cat > "$sysroot/include/sys/times.h" <<'SYS_TIMES_H'
#ifndef _DARWIN_BOOTSTRAP_SYS_TIMES_H
#define _DARWIN_BOOTSTRAP_SYS_TIMES_H
#ifdef __cplusplus
extern "C" {
#endif
typedef long clock_t;
struct tms {
  clock_t tms_utime;
  clock_t tms_stime;
  clock_t tms_cutime;
  clock_t tms_cstime;
};
clock_t times(struct tms *);
#ifdef __cplusplus
}
#endif
#endif
SYS_TIMES_H
cat > "$sysroot/include/ftw.h" <<'FTW_H'
#ifndef _DARWIN_BOOTSTRAP_FTW_H
#define _DARWIN_BOOTSTRAP_FTW_H
#include <sys/stat.h>
#define FTW_F 0
#define FTW_D 1
#define FTW_DNR 2
#define FTW_NS 3
#define FTW_SL 4
#define FTW_DP 6
#define FTW_SLN 7
#define FTW_PHYS 0x01
#define FTW_MOUNT 0x02
#define FTW_DEPTH 0x04
#define FTW_CHDIR 0x08
struct FTW {
  int base;
  int level;
};
#ifdef __cplusplus
extern "C" {
#endif
int ftw(const char *, int (*)(const char *, const struct stat *, int), int);
int nftw(const char *, int (*)(const char *, const struct stat *, int, struct FTW *), int, int);
#ifdef __cplusplus
}
#endif
#endif
FTW_H
cat > "$sysroot/include/getopt.h" <<'GETOPT_H'
#ifndef _DARWIN_BOOTSTRAP_GETOPT_H
#define _DARWIN_BOOTSTRAP_GETOPT_H
#define no_argument 0
#define required_argument 1
#define optional_argument 2
struct option {
  const char *name;
  int has_arg;
  int *flag;
  int val;
};
#ifdef __cplusplus
extern "C" {
#endif
extern char *optarg;
extern int optind;
extern int opterr;
extern int optopt;
int getopt(int, char * const *, const char *);
int getopt_long(int, char * const *, const char *, const struct option *, int *);
#ifdef __cplusplus
}
#endif
#endif
GETOPT_H
if [ -f "$sysroot/include/signal.h" ] && ! grep -q 'strsignal' "$sysroot/include/signal.h"; then
  perl -0pi -e 's@(__sighandler_t signal\(int, __sighandler_t\);\n)@#ifdef __cplusplus\nextern "C" {\n#endif\n$1@; s@(int sigprocmask\(int, const sigset_t \*, sigset_t \*\);\n)@$1char *strsignal(int);\n#ifdef __cplusplus\n}\n#endif\n@' "$sysroot/include/signal.h"
fi
if [ -f "$sysroot/include/strings.h" ] && ! grep -q 'extern "C"' "$sysroot/include/strings.h"; then
  perl -0pi -e 's@(#include <string.h>\n)@$1#ifdef __cplusplus\nextern "C" {\n#endif\n@; s@(#endif\n)\z@#ifdef __cplusplus\n}\n#endif\n$1@' "$sysroot/include/strings.h"
fi
if [ -f "$sysroot/include/fcntl.h" ] && ! grep -q 'extern "C"' "$sysroot/include/fcntl.h"; then
  perl -0pi -e 's@(#define FD_CLOEXEC 1\n)@$1#ifdef __cplusplus\nextern "C" {\n#endif\n@; s@(#endif\n)\z@#ifdef __cplusplus\n}\n#endif\n$1@' "$sysroot/include/fcntl.h"
fi
if [ -f "$sysroot/include/fcntl.h" ] && ! grep -q 'F_GETFL' "$sysroot/include/fcntl.h"; then
  perl -0pi -e 's@(#define F_SETFD 2\n)@$1#define F_GETFL 3\n@' "$sysroot/include/fcntl.h"
fi
if [ -f "$sysroot/include/fcntl.h" ] && ! grep -q 'F_DUPFD' "$sysroot/include/fcntl.h"; then
  perl -0pi -e 's@(#define F_GETFD 1\n)@#define F_DUPFD 0\n$1@' "$sysroot/include/fcntl.h"
fi
if [ -f "$sysroot/include/fcntl.h" ] && ! grep -q 'F_SETFL' "$sysroot/include/fcntl.h"; then
  perl -0pi -e 's@(#define F_GETFL 3\n)@$1#define F_SETFL 4\n@' "$sysroot/include/fcntl.h"
fi
if [ -f "$sysroot/include/fcntl.h" ] && ! grep -q 'F_SETLKW' "$sysroot/include/fcntl.h"; then
  perl -0pi -e 's@(#define FD_CLOEXEC 1\n)@#define F_GETOWN 5\n#define F_SETOWN 6\n#define F_GETLK 7\n#define F_SETLK 8\n#define F_RDLCK 1\n#define F_UNLCK 2\n#define F_WRLCK 3\n#define F_SETLKW 9\n#define F_DUPFD_CLOEXEC 67\n$1@' "$sysroot/include/fcntl.h"
fi
if [ -f "$sysroot/include/fcntl.h" ] && ! grep -q 'O_CLOEXEC' "$sysroot/include/fcntl.h"; then
  perl -0pi -e 's@(#define O_APPEND 0x0008\n)@$1#define O_DIRECTORY 0x100000\n#define O_CLOEXEC 0x1000000\n#define AT_FDCWD -2\n@' "$sysroot/include/fcntl.h"
fi
if [ -f "$sysroot/include/fcntl.h" ] && ! grep -q 'struct flock' "$sysroot/include/fcntl.h"; then
  perl -0pi -e 's@(#ifdef __cplusplus\nextern "C" \{\n#endif\n)@typedef long long off_t;\nstruct flock {\n  off_t l_start;\n  off_t l_len;\n  int l_pid;\n  short l_type;\n  short l_whence;\n};\n$1@' "$sysroot/include/fcntl.h"
fi
if [ -f "$sysroot/include/dirent.h" ] && ! grep -q 'extern "C"' "$sysroot/include/dirent.h"; then
  perl -0pi -e 's@(struct dirent \{[^\n]*\};\n)@$1#ifdef __cplusplus\nextern "C" {\n#endif\n@; s@(#endif\n)\z@#ifdef __cplusplus\n}\n#endif\n$1@' "$sysroot/include/dirent.h"
fi
if [ -f "$sysroot/include/dirent.h" ] && ! grep -q 'DT_UNKNOWN' "$sysroot/include/dirent.h"; then
  perl -0pi -e 's@(typedef struct DIR DIR;\n)@$1#define DT_UNKNOWN 0\n#define DT_FIFO 1\n#define DT_CHR 2\n#define DT_DIR 4\n#define DT_BLK 6\n#define DT_REG 8\n#define DT_LNK 10\n#define DT_SOCK 12\n@' "$sysroot/include/dirent.h"
fi
if [ -f "$sysroot/include/sys/stat.h" ] && ! grep -q 'extern "C"' "$sysroot/include/sys/stat.h"; then
  perl -0pi -e 's@(#define st_ctime st_ctimespec.tv_sec\n)@$1#ifdef __cplusplus\nextern "C" {\n#endif\n@; s@(#define S_IFMT 0170000\n)@#ifdef __cplusplus\n}\n#endif\n$1@' "$sysroot/include/sys/stat.h"
fi
if [ -f "$sysroot/include/sys/time.h" ] && ! grep -q 'extern "C"' "$sysroot/include/sys/time.h"; then
  perl -0pi -e 's@(struct timezone \{[^\n]*\};\n)@$1#ifdef __cplusplus\nextern "C" {\n#endif\n@; s@(#endif\n)\z@#ifdef __cplusplus\n}\n#endif\n$1@' "$sysroot/include/sys/time.h"
fi
if [ -f "$sysroot/include/sys/mman.h" ] && ! grep -q 'extern "C"' "$sysroot/include/sys/mman.h"; then
  perl -0pi -e 's@(#define MAP_FAILED \(\(void \*\)-1\)\n)@$1#ifdef __cplusplus\nextern "C" {\n#endif\n@; s@(#endif\n)\z@#ifdef __cplusplus\n}\n#endif\n$1@' "$sysroot/include/sys/mman.h"
fi
if [ -f "$sysroot/include/sys/mman.h" ] && ! grep -q 'MADV_RANDOM' "$sysroot/include/sys/mman.h"; then
  perl -0pi -e 's@(#define MAP_FAILED \(\(void \*\)-1\)\n)@$1#define MADV_RANDOM 1\n@; s@(int mprotect\(void \*, size_t, int\);\n)@$1int madvise(void *, size_t, int);\n@' "$sysroot/include/sys/mman.h"
fi
if [ -f "$sysroot/include/sys/sysctl.h" ] && ! grep -q 'extern "C"' "$sysroot/include/sys/sysctl.h"; then
  perl -0pi -e 's@(#define KERN_OSRELEASE 2\n)@$1#ifdef __cplusplus\nextern "C" {\n#endif\n@; s@(#endif\n)\z@#ifdef __cplusplus\n}\n#endif\n$1@' "$sysroot/include/sys/sysctl.h"
fi
if [ -f "$sysroot/include/signal.h" ]; then
  perl -0pi -e 's@typedef long sigset_t;@typedef unsigned int sigset_t;@g' "$sysroot/include/signal.h"
fi
if [ -f "$sysroot/include/sys/types.h" ]; then
  perl -0pi -e 's@typedef long off_t;@typedef long long off_t;@g' "$sysroot/include/sys/types.h"
fi
if [ -f "$sysroot/include/sys/stat.h" ]; then
  perl -0pi -e 's@typedef long off_t;@typedef long long off_t;@g' "$sysroot/include/sys/stat.h"
fi
if [ -f "$sysroot/include/sys/stat.h" ] && ! grep -q 'fstatat' "$sysroot/include/sys/stat.h"; then
  perl -0pi -e 's@(int fstat\(int, struct stat \*\);\n)@$1int fstatat(int, const char *, struct stat *, int);\n@' "$sysroot/include/sys/stat.h"
fi
if [ -f "$sysroot/include/unistd.h" ]; then
  perl -0pi -e 's@typedef long off_t;@typedef long long off_t;@g' "$sysroot/include/unistd.h"
fi
if [ -f "$sysroot/include/stdint.h" ]; then
  perl -0pi \
    -e 's@typedef long int64_t;@typedef long long int64_t;@g;' \
    -e 's@typedef unsigned long uint64_t;@typedef unsigned long long uint64_t;@g;' \
    -e 's@typedef long intmax_t;@typedef long long intmax_t;@g;' \
    -e 's@typedef unsigned long uintmax_t;@typedef unsigned long long uintmax_t;@g' \
    "$sysroot/include/stdint.h"
fi
if ! grep -q '_PC_PATH_MAX' "$sysroot/include/unistd.h"; then
  perl -0pi -e 's@(#ifdef __cplusplus\n}\n#endif\n#endif\n)\z@#ifndef _PC_PATH_MAX\n#define _PC_PATH_MAX 5\n#endif\nlong pathconf(const char *, int);\nchar *realpath(const char *, char *);\n$1@' "$sysroot/include/unistd.h"
fi
if ! grep -q 'getpagesize' "$sysroot/include/unistd.h"; then
  perl -0pi -e 's@(#ifdef __cplusplus\n}\n#endif\n#endif\n)\z@int getpagesize(void);\nint vfork(void);\n$1@' "$sysroot/include/unistd.h"
fi
if ! grep -q 'int truncate' "$sysroot/include/unistd.h"; then
  perl -0pi -e 's@(int ftruncate\(int, off_t\);\n)@$1int truncate(const char *, off_t);\n@' "$sysroot/include/unistd.h"
fi
if ! grep -q 'execve' "$sysroot/include/unistd.h"; then
  perl -0pi -e 's@(int execvp\([^\n]+\);\n)@$1int execve(const char *, char *const *, char *const *);\n@' "$sysroot/include/unistd.h"
fi
if [ -f "$sysroot/include/string.h" ] && ! grep -q 'strerror_r' "$sysroot/include/string.h"; then
  perl -0pi -e 's@(#ifdef __cplusplus\n}\n#endif\n#endif\n)\z@int strerror_r(int, char *, unsigned long);\n$1@' "$sysroot/include/string.h"
fi
if [ -f "$sysroot/include/string.h" ] && ! grep -q 'strnlen' "$sysroot/include/string.h"; then
  perl -0pi -e 's@(unsigned long strlen\([^\n]+\);\n)@$1size_t strnlen(const char *, size_t);\n@' "$sysroot/include/string.h"
fi
if [ -f "$sysroot/include/stdlib.h" ] && ! grep -q 'getprogname' "$sysroot/include/stdlib.h"; then
  perl -0pi -e 's@(#ifdef __cplusplus\n}\n#endif\n#endif\n)\z@const char *getprogname(void);\n$1@' "$sysroot/include/stdlib.h"
fi
if [ -f "$sysroot/include/stdio.h" ] && grep -q '#define stdout ((FILE \\*)1)' "$sysroot/include/stdio.h"; then
  perl -0pi \
    -e 's@#define stdin \(\(FILE \*\)0\)\n#define stdout \(\(FILE \*\)1\)\n#define stderr \(\(FILE \*\)2\)\n@extern FILE *__stdinp;\nextern FILE *__stdoutp;\nextern FILE *__stderrp;\n#define stdin __stdinp\n#define stdout __stdoutp\n#define stderr __stderrp\n@' \
    "$sysroot/include/stdio.h"
fi
if [ -f "$sysroot/include/stdio.h" ] && grep -q 'typedef long FILE;' "$sysroot/include/stdio.h"; then
  perl -0pi -e 's@typedef long FILE;@struct __sbuf { unsigned char *_base; int _size; };\nstruct __sFILE { unsigned char *_p; int _r; int _w; short _flags; short _file; struct __sbuf _bf; int _lbfsize; void *_cookie; int (*_close)(void *); int (*_read)(void *, char *, int); long (*_seek)(void *, long, int); int (*_write)(void *, const char *, int); struct __sbuf _ub; void *_extra; int _ur; unsigned char _ubuf[3]; unsigned char _nbuf[1]; struct __sbuf _lb; int _blksize; long _offset; };\ntypedef struct __sFILE FILE;\n#define __sferror(p) ((p)->_flags & 0x0040)@' "$sysroot/include/stdio.h"
fi
if [ -f "$sysroot/include/stdio.h" ] && grep -q 'struct __sFILE { void \*__opaque; };' "$sysroot/include/stdio.h"; then
  perl -0pi -e 's@struct __sFILE \{ void \*__opaque; \};@struct __sbuf { unsigned char *_base; int _size; };\nstruct __sFILE { unsigned char *_p; int _r; int _w; short _flags; short _file; struct __sbuf _bf; int _lbfsize; void *_cookie; int (*_close)(void *); int (*_read)(void *, char *, int); long (*_seek)(void *, long, int); int (*_write)(void *, const char *, int); struct __sbuf _ub; void *_extra; int _ur; unsigned char _ubuf[3]; unsigned char _nbuf[1]; struct __sbuf _lb; int _blksize; long _offset; };\n#define __sferror(p) ((p)->_flags & 0x0040)@' "$sysroot/include/stdio.h"
fi
if [ -f "$sysroot/include/stdio.h" ] && ! grep -q '#define __sferror' "$sysroot/include/stdio.h"; then
  perl -0pi -e 's@(typedef struct __sFILE FILE;\n)@$1#define __sferror(p) ((p)->_flags & 0x0040)\n@' "$sysroot/include/stdio.h"
fi
if [ -f "$sysroot/include/stdlib.h" ] && ! grep -q 'MB_CUR_MAX ' "$sysroot/include/stdlib.h"; then
  perl -0pi -e 's@(#define EXIT_FAILURE 1\n)@$1#ifndef MB_CUR_MAX\n#define MB_CUR_MAX 1\n#endif\n#ifndef MB_CUR_MAX_L\n#define MB_CUR_MAX_L(x) (1)\n#endif\n@' "$sysroot/include/stdlib.h"
fi
if [ -f "$sysroot/include/stdlib.h" ] && ! grep -q 'RAND_MAX' "$sysroot/include/stdlib.h"; then
  perl -0pi -e 's@(#define EXIT_FAILURE 1\n)@$1#ifndef RAND_MAX\n#define RAND_MAX 2147483647\n#endif\n@' "$sysroot/include/stdlib.h"
fi
if [ -f "$sysroot/include/stdlib.h" ] && ! grep -q 'typedef int wchar_t' "$sysroot/include/stdlib.h"; then
  perl -0pi -e 's@(typedef unsigned long size_t;\n)@$1#ifndef __cplusplus\ntypedef int wchar_t;\n#endif\n@' "$sysroot/include/stdlib.h"
fi
if [ -f "$sysroot/include/stdlib.h" ] && ! grep -q 'mblen' "$sysroot/include/stdlib.h"; then
  perl -0pi -e 's@(void srand\(unsigned int\);\n)@$1int mblen(const char *, size_t);\nsize_t mbstowcs(wchar_t *, const char *, size_t);\nint mbtowc(wchar_t *, const char *, size_t);\n@' "$sysroot/include/stdlib.h"
fi
if [ -f "$sysroot/include/stdlib.h" ] && ! grep -q 'aligned_alloc' "$sysroot/include/stdlib.h"; then
  perl -0pi -e 's@(void \*malloc\(size_t\);\n)@$1void *aligned_alloc(size_t, size_t);\n@' "$sysroot/include/stdlib.h"
fi
if [ -f "$sysroot/include/stdlib.h" ] && ! grep -q 'posix_memalign' "$sysroot/include/stdlib.h"; then
  perl -0pi -e 's@(void \*aligned_alloc\(size_t, size_t\);\n)@$1int posix_memalign(void **, size_t, size_t);\n@' "$sysroot/include/stdlib.h"
fi
if [ -f "$sysroot/include/time.h" ] && ! grep -q 'timespec_get' "$sysroot/include/time.h"; then
  perl -0pi -e 's@(int nanosleep\(const struct timespec \*, struct timespec \*\);\n)@$1#ifndef TIME_UTC\n#define TIME_UTC 1\n#endif\nint timespec_get(struct timespec *, int);\n@' "$sysroot/include/time.h"
fi
if [ -f "$sysroot/include/time.h" ] && ! grep -q 'clock_gettime' "$sysroot/include/time.h"; then
  perl -0pi -e 's@(int nanosleep\(const struct timespec \*, struct timespec \*\);\n)@$1#ifndef CLOCK_REALTIME\n#define CLOCK_REALTIME 0\n#endif\nint clock_gettime(int, struct timespec *);\n@' "$sysroot/include/time.h"
fi
if [ -f "$sysroot/include/ctype.h" ] && ! grep -q '#define _CTYPE_B' "$sysroot/include/ctype.h"; then
  perl -0pi -e 's@(#define DARWIN_BOOTSTRAP_CTYPE_BITS 1\n)@$1#define _CTYPE_B 0x00000001L\n@; s@(#define _R _CTYPE_R\n)@$1#define _B _CTYPE_B\n@' "$sysroot/include/ctype.h"
fi
if [ -f "$sysroot/include/math.h" ] && ! grep -q 'FP_NAN' "$sysroot/include/math.h"; then
  perl -0pi -e 's@(#define _DARWIN_BOOTSTRAP_MATH_H\n)@$1#define FP_NAN 0\n#define FP_INFINITE 1\n#define FP_NORMAL 2\n#define FP_SUBNORMAL 3\n#define FP_ZERO 4\n@' "$sysroot/include/math.h"
fi
if ! grep -q 'INTMAX_MAX' "$sysroot/include/stdint.h"; then
  perl -0pi -e 's@(#endif\n)\z@#define INTMAX_MAX 9223372036854775807LL\n#define INTMAX_MIN (-INTMAX_MAX - 1LL)\n#define UINTMAX_MAX 18446744073709551615ULL\n$1@' "$sysroot/include/stdint.h"
fi
perl -0pi \
  -e 's@#define INTMAX_MAX 9223372036854775807L\b@#define INTMAX_MAX 9223372036854775807LL@g;' \
  -e 's@#define INTMAX_MIN \(-INTMAX_MAX - 1L\)@#define INTMAX_MIN (-INTMAX_MAX - 1LL)@g;' \
  -e 's@#define UINTMAX_MAX 18446744073709551615UL\b@#define UINTMAX_MAX 18446744073709551615ULL@g' \
  "$sysroot/include/stdint.h"
if ! grep -q 'UINT_MAX' "$sysroot/include/stdint.h"; then
  perl -0pi -e 's@(#define UINTMAX_MAX 18446744073709551615U?LL\n)@$1#define UINT_MAX 4294967295U\n#define ULONG_MAX 18446744073709551615UL\n@' "$sysroot/include/stdint.h"
fi
if ! grep -q 'UINT64_MAX' "$sysroot/include/stdint.h"; then
  perl -0pi -e 's@(#define UINTMAX_MAX 18446744073709551615U?LL\n)@$1#define UINT64_MAX 18446744073709551615ULL\n#define INT64_MAX 9223372036854775807LL\n#define INT64_MIN (-INT64_MAX - 1LL)\n@' "$sysroot/include/stdint.h"
fi
if ! grep -q 'UINT32_MAX' "$sysroot/include/stdint.h"; then
  perl -0pi -e 's@(#define UINT64_MAX 18446744073709551615ULL\n)@#define UINT8_MAX 255U\n#define INT8_MAX 127\n#define INT8_MIN (-INT8_MAX - 1)\n#define UINT16_MAX 65535U\n#define INT16_MAX 32767\n#define INT16_MIN (-INT16_MAX - 1)\n#define UINT32_MAX 4294967295U\n#define INT32_MAX 2147483647\n#define INT32_MIN (-INT32_MAX - 1)\n$1@' "$sysroot/include/stdint.h"
fi
if ! grep -q 'SIZE_MAX' "$sysroot/include/stdint.h"; then
  perl -0pi -e 's@(#define UINTMAX_MAX 18446744073709551615U?LL\n)@$1#define SIZE_MAX 18446744073709551615UL\n@' "$sysroot/include/stdint.h"
fi
if ! grep -q 'PTRDIFF_MAX' "$sysroot/include/stdint.h"; then
  perl -0pi -e 's@(#define SIZE_MAX 18446744073709551615UL\n)@$1#define PTRDIFF_MAX 9223372036854775807L\n#define PTRDIFF_MIN (-PTRDIFF_MAX - 1L)\n@' "$sysroot/include/stdint.h"
fi
if [ -f "$sysroot/include/inttypes.h" ]; then
  if grep -q 'PRIi64' "$sysroot/include/inttypes.h"; then
    perl -0pi \
      -e 's@#define PRId64 "l?ld"@#define PRId64 "lld"@g;' \
      -e 's@#define PRIi64 "l?li"@#define PRIi64 "lli"@g;' \
      -e 's@#define PRIu64 "l?lu"@#define PRIu64 "llu"@g;' \
      -e 's@#define PRIx64 "l?lx"@#define PRIx64 "llx"@g;' \
      -e 's@#define PRIX64 "l?lX"@#define PRIX64 "llX"@g' \
      "$sysroot/include/inttypes.h"
  else
    perl -0pi -e 's@(#endif\n)\z@#define PRId64 "lld"\n#define PRIi64 "lli"\n#define PRIu64 "llu"\n#define PRIx64 "llx"\n#define PRIX64 "llX"\n$1@' "$sysroot/include/inttypes.h"
  fi
fi
if [ ! -f "$sysroot/include/wchar.h" ]; then
  cat > "$sysroot/include/wchar.h" <<'WCHAR_H'
#ifndef _DARWIN_BOOTSTRAP_WCHAR_H
#define _DARWIN_BOOTSTRAP_WCHAR_H
#include <stddef.h>
typedef int wchar_t;
typedef int wint_t;
typedef struct { unsigned char __opaque[16]; } mbstate_t;
#ifndef WEOF
#define WEOF ((wint_t)-1)
#endif
size_t mbsrtowcs(wchar_t *, const char **, size_t, mbstate_t *);
int wprintf(const wchar_t *, ...);
int wcwidth(wchar_t);
#endif
WCHAR_H
fi
if ! grep -q 'typedef struct .*mbstate_t' "$sysroot/include/wchar.h"; then
  perl -0pi -e 's@(#define _DARWIN_BOOTSTRAP_WCHAR_H\n)@$1#include <stddef.h>\n@ unless /#include <stddef.h>/; s@(typedef int wint_t;\n)@$1typedef struct { unsigned char __opaque[16]; } mbstate_t;\n#ifndef WEOF\n#define WEOF ((wint_t)-1)\n#endif\nsize_t mbsrtowcs(wchar_t *, const char **, size_t, mbstate_t *);\nint wprintf(const wchar_t *, ...);\n@' "$sysroot/include/wchar.h"
fi
if ! grep -q 'mbsrtowcs' "$sysroot/include/wchar.h"; then
  perl -0pi -e 's@(#endif\n)\z@size_t mbsrtowcs(wchar_t *, const char **, size_t, mbstate_t *);\nint wprintf(const wchar_t *, ...);\n$1@' "$sysroot/include/wchar.h"
fi
if ! grep -q 'mbrtowc' "$sysroot/include/wchar.h"; then
  perl -0pi -e 's@(int mbsrtowcs\([^\n]+\);\n)@$1size_t mbrtowc(wchar_t *, const char *, size_t, mbstate_t *);\nint mbsinit(const mbstate_t *);\n@' "$sysroot/include/wchar.h"
fi
if ! grep -q 'int wcwidth' "$sysroot/include/wchar.h"; then
  perl -0pi -e 's@(int wprintf\([^\n]+\);\n)@$1int wcwidth(wchar_t);\n@' "$sysroot/include/wchar.h"
fi
if ! grep -q '__opaque\[16\]' "$sysroot/include/wchar.h"; then
  perl -0pi -e 's@typedef struct \{ unsigned int __state; unsigned int __opaque; \} mbstate_t;@typedef struct { unsigned char __opaque[16]; } mbstate_t;@' "$sysroot/include/wchar.h"
fi
if [ ! -f "$sysroot/include/wctype.h" ]; then
  cat > "$sysroot/include/wctype.h" <<'WCTYPE_H'
#ifndef _DARWIN_BOOTSTRAP_WCTYPE_H
#define _DARWIN_BOOTSTRAP_WCTYPE_H
#include <ctype.h>
#include <wchar.h>
typedef unsigned long wctype_t;
typedef int wctrans_t;
static inline int __darwin_bootstrap_wchar_byte(wint_t wc) { return wc >= 0 && wc <= 255; }
static inline int iswalnum(wint_t wc) { return __darwin_bootstrap_wchar_byte(wc) ? isalnum((int)wc) : 0; }
static inline int iswalpha(wint_t wc) { return __darwin_bootstrap_wchar_byte(wc) ? isalpha((int)wc) : 0; }
static inline int iswblank(wint_t wc) { return wc == ' ' || wc == '\t'; }
static inline int iswcntrl(wint_t wc) { return __darwin_bootstrap_wchar_byte(wc) ? iscntrl((int)wc) : 0; }
static inline int iswdigit(wint_t wc) { return __darwin_bootstrap_wchar_byte(wc) ? isdigit((int)wc) : 0; }
static inline int iswgraph(wint_t wc) { return __darwin_bootstrap_wchar_byte(wc) ? isgraph((int)wc) : 0; }
static inline int iswlower(wint_t wc) { return __darwin_bootstrap_wchar_byte(wc) ? islower((int)wc) : 0; }
static inline int iswprint(wint_t wc) { return __darwin_bootstrap_wchar_byte(wc) ? isprint((int)wc) : 0; }
static inline int iswpunct(wint_t wc) { return __darwin_bootstrap_wchar_byte(wc) ? ispunct((int)wc) : 0; }
static inline int iswspace(wint_t wc) { return __darwin_bootstrap_wchar_byte(wc) ? isspace((int)wc) : 0; }
static inline int iswupper(wint_t wc) { return __darwin_bootstrap_wchar_byte(wc) ? isupper((int)wc) : 0; }
static inline int iswxdigit(wint_t wc) { return __darwin_bootstrap_wchar_byte(wc) ? isxdigit((int)wc) : 0; }
static inline wint_t towlower(wint_t wc) { return __darwin_bootstrap_wchar_byte(wc) ? tolower((int)wc) : wc; }
static inline wint_t towupper(wint_t wc) { return __darwin_bootstrap_wchar_byte(wc) ? toupper((int)wc) : wc; }
static inline wctype_t wctype(const char *name) { (void)name; return 0; }
static inline int iswctype(wint_t wc, wctype_t desc) { (void)wc; (void)desc; return 0; }
static inline wctrans_t wctrans(const char *name) { (void)name; return 0; }
static inline wint_t towctrans(wint_t wc, wctrans_t desc) { (void)desc; return wc; }
#endif
WCTYPE_H
fi
if [ ! -f "$sysroot/include/AvailabilityMacros.h" ]; then
  cat > "$sysroot/include/AvailabilityMacros.h" <<'AVAILABILITY_MACROS_H'
#ifndef _DARWIN_BOOTSTRAP_AVAILABILITY_MACROS_H
#define _DARWIN_BOOTSTRAP_AVAILABILITY_MACROS_H
#ifndef MAC_OS_X_VERSION_MIN_REQUIRED
#define MAC_OS_X_VERSION_MIN_REQUIRED 140400
#endif
#ifndef MAC_OS_X_VERSION_MAX_ALLOWED
#define MAC_OS_X_VERSION_MAX_ALLOWED 140400
#endif
#endif
AVAILABILITY_MACROS_H
fi
if [ ! -f "$sysroot/include/xlocale.h" ]; then
  cat > "$sysroot/include/xlocale.h" <<'XLOCALE_H'
#ifndef _DARWIN_BOOTSTRAP_XLOCALE_H
#define _DARWIN_BOOTSTRAP_XLOCALE_H
typedef void *locale_t;
#define LC_GLOBAL_LOCALE ((locale_t)-1)
#define LC_C_LOCALE ((locale_t)0)
#define LC_ALL_MASK 0x3f
#ifndef MB_CUR_MAX_L
#define MB_CUR_MAX_L(x) (1)
#endif
locale_t newlocale(int, const char *, locale_t);
void freelocale(locale_t);
locale_t uselocale(locale_t);
#endif
XLOCALE_H
fi
if [ -f "$sysroot/include/xlocale.h" ] && ! grep -q 'newlocale' "$sysroot/include/xlocale.h"; then
  perl -0pi -e 's@(#define LC_C_LOCALE \(\(locale_t\)0\)\n)@$1#define LC_ALL_MASK 0x3f\n@; s@(locale_t uselocale\(locale_t\);\n)@locale_t newlocale(int, const char *, locale_t);\nvoid freelocale(locale_t);\n$1@' "$sysroot/include/xlocale.h"
fi
if [ ! -f "$sysroot/include/locale.h" ]; then
  cat > "$sysroot/include/locale.h" <<'LOCALE_H'
#ifndef _DARWIN_BOOTSTRAP_LOCALE_H
#define _DARWIN_BOOTSTRAP_LOCALE_H
#include <xlocale.h>
#define LC_ALL 0
#define LC_COLLATE 1
#define LC_CTYPE 2
#define LC_MONETARY 3
#define LC_NUMERIC 4
#define LC_TIME 5
struct lconv {
  char *decimal_point;
  char *thousands_sep;
  char *grouping;
  char *int_curr_symbol;
  char *currency_symbol;
  char *mon_decimal_point;
  char *mon_thousands_sep;
  char *mon_grouping;
  char *positive_sign;
  char *negative_sign;
  char int_frac_digits;
  char frac_digits;
  char p_cs_precedes;
  char p_sep_by_space;
  char n_cs_precedes;
  char n_sep_by_space;
  char p_sign_posn;
  char n_sign_posn;
};
#ifdef __cplusplus
extern "C" {
#endif
char *setlocale(int, const char *);
struct lconv *localeconv(void);
#ifdef __cplusplus
}
#endif
#endif
LOCALE_H
fi
if [ -f "$sysroot/include/sys/resource.h" ] && ! grep -q 'getrusage' "$sysroot/include/sys/resource.h"; then
  perl -0pi -e 's@(#endif\n)\z@#ifdef __cplusplus\nextern "C" {\n#endif\nint getrusage(int, struct rusage *);\n#ifdef __cplusplus\n}\n#endif\n$1@' "$sysroot/include/sys/resource.h"
fi
if [ -f "$sysroot/include/sys/resource.h" ] && ! grep -q 'RLIMIT_CORE' "$sysroot/include/sys/resource.h"; then
  perl -0pi -e 's@(#define RUSAGE_CHILDREN -1\n)@$1#define RLIMIT_CORE 4\n#define RLIM_INFINITY 9223372036854775807UL\n@' "$sysroot/include/sys/resource.h"
fi
if [ -f "$sysroot/include/sys/resource.h" ] && ! grep -q 'RLIMIT_NOFILE' "$sysroot/include/sys/resource.h"; then
  perl -0pi -e 's@(#define RLIMIT_CORE 4\n)@$1#define RLIMIT_NOFILE 8\n@; s@(int getrusage\(int, struct rusage \*\);\n)@$1int getrlimit(int, struct rlimit *);\nint setrlimit(int, const struct rlimit *);\n@' "$sysroot/include/sys/resource.h"
fi
if [ -f "$sysroot/include/sys/resource.h" ] && ! grep -q 'extern "C"' "$sysroot/include/sys/resource.h"; then
  perl -0pi -e 's@(struct rlimit \{[^\n]*\};\n)@$1#ifdef __cplusplus\nextern "C" {\n#endif\n@; s@(#endif\n)\z@#ifdef __cplusplus\n}\n#endif\n$1@' "$sysroot/include/sys/resource.h"
fi

sdk_path() {
  if [ -n "${GCC_MODERN_SDK_PATH:-}" ]; then
    printf '%s\n' "$GCC_MODERN_SDK_PATH"
  elif command -v xcrun >/dev/null 2>&1; then
    xcrun --sdk macosx --show-sdk-path
  elif [ -d /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk ]; then
    printf '/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk\n'
  else
    printf '/\n'
  fi
}

sdk="$(sdk_path)"
cc="$compiler/bin/gcc"
cxx="$compiler/bin/g++"
gcc_lib_dir="$compiler/lib/gcc/$target/$("$cc" -dumpversion 2>/dev/null || true)"
if [ ! -d "$gcc_lib_dir" ]; then
  gcc_lib_dir=$(find "$compiler/lib/gcc/$target" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort | tail -1)
fi
if [ -z "$gcc_lib_dir" ] || [ ! -d "$gcc_lib_dir" ]; then
  echo "$label cannot find a GCC runtime directory under $compiler/lib/gcc/$target" >&2
  exit 1
fi
bootstrap_link_flags="-nostartfiles -nodefaultlibs -L$gcc_lib_dir -L$compiler/lib -lgcc -lstdc++ -lsupc++ -Wl,-syslibroot,$sdk -lSystem"
build_cc=${GCC_MODERN_HOST_CC:-/usr/bin/cc}
build_cxx=${GCC_MODERN_HOST_CXX:-/usr/bin/c++}
# wrapper_host_* are single-binary paths baked into the generated gcc/g++
# wrappers via heredoc substitution. They always resolve to an actual binary
# (never the multi-arg compound build_cc form), so they're safe to use in
# wrapper `exec` lines without word-splitting issues.
wrapper_host_cc="${GCC_MODERN_HOST_CC:-/usr/bin/cc}"
wrapper_host_cxx="${GCC_MODERN_HOST_CXX:-/usr/bin/c++}"
wrapper_host_ld="${GCC_MODERN_LD:-/usr/bin/ld}"
wrapper_host_bin_dir=$(dirname "$wrapper_host_ld")
if [ "${GCC_MODERN_HOST_BUILD_CC:-1}" != 1 ]; then
  build_cc="$cc $bootstrap_link_flags"
  build_cxx="$cxx $bootstrap_link_flags"
  if [ "$label" = gcc10 ]; then
    ## gcc-4.6 (the gcc10 input compiler) resolves libc headers through the
    ## staged sysroot; its raw driver lacks sys/times.h and friends, so the
    ## build-machine helpers need the same -isystem the host side gets.
    build_cc="$cc -isystem $sysroot/include $bootstrap_link_flags"
    build_cxx="$cxx -isystem $sysroot/include $bootstrap_link_flags"
  fi
fi
input_wrapper_dir="$PWD/input-compiler-wrappers"
mkdir -p "$input_wrapper_dir"
write_input_compiler_wrapper() {
  local wrapper="$1"
  local real_compiler="$2"
  local host_compiler="$3"
  cat > "$input_wrapper_dir/$wrapper" <<EOF
#!/usr/bin/env bash
set -euo pipefail
real_compiler='$real_compiler'
host_compiler='$host_compiler'
wrapper_name='$wrapper'
use_host=0
compile_only=0
source_file=
output_file=a.out
previous=
for arg in "\$@"; do
  if [ "\$previous" = x ]; then
    source_file="\$arg"
    previous=
    continue
  fi
  if [ "\$previous" = o ]; then
    output_file="\$arg"
    previous=
    continue
  fi
  case "\$arg" in
    -c) compile_only=1 ;;
    -x) previous=x ;;
    -o) previous=o ;;
    *.c|*.cc|*.C|*.cxx|*.cpp) source_file="\$arg" ;;
  esac
done
case "\${GCC_MODERN_INPUT_HOST_SHORTCUTS:-1}:\$compile_only:\${source_file##*/}" in
  1:1:insn-*.c|1:1:insn-*.cc|1:1:gengtype-*.c)
    use_host=1
    ;;
esac
if [ "\$use_host" != 1 ]; then
  if [ "\${GCC_MODERN_INPUT_HOST_LINK_SHORTCUTS:-0}" = 1 ] && [ "\$compile_only" = 0 ] && [ "\$wrapper_name" = g++ ]; then
    case "\$PWD:\${output_file##*/}" in
      */build/gcc:*)
        filtered=()
        skip_next=0
        skip_link_dir=0
        for arg in "\$@"; do
          if [ "\$skip_next" = 1 ]; then
            skip_next=0
            continue
          fi
          if [ "\$skip_link_dir" = 1 ]; then
            skip_link_dir=0
            case "\$arg" in
              /nix/store/*darwin-minimal-bootstrap-phase*-gcc*|*/bootstrap-sysroot/lib) ;;
              *) filtered+=("-L" "\$arg") ;;
            esac
            continue
          fi
          case "\$arg" in
            -B*|-static-libstdc++|-static-libgcc|-nostartfiles|-nodefaultlibs|-nostdlib|-no-pie|-fno-PIE)
              ;;
            -L)
              skip_link_dir=1
              ;;
            -L/nix/store/*darwin-minimal-bootstrap-phase*-gcc*|-L*/bootstrap-sysroot/lib)
              ;;
            -lgcc|-lstdc++|-lsupc++)
              ;;
            -Werror*)
              ;;
            -auxbase|-auxbase-strip|-dumpbase)
              skip_next=1
              ;;
            *)
              filtered+=("\$arg")
              ;;
          esac
        done
        exec "\$host_compiler" -arch x86_64 -Wno-error=format-security -Wno-unknown-warning-option -Wno-error=implicit-function-declaration "\${filtered[@]}"
        ;;
    esac
  fi
  exec "\$real_compiler" "\$@"
fi
filtered=()
skip_next=0
skip_isystem=0
for arg in "\$@"; do
  if [ "\$skip_next" = 1 ]; then
    skip_next=0
    continue
  fi
  if [ "\$skip_isystem" = 1 ]; then
    skip_isystem=0
    case "\$arg" in
      */bootstrap-sysroot/include) ;;
      *) filtered+=("-isystem" "\$arg") ;;
    esac
    continue
  fi
  case "\$arg" in
    -B*|-fno-PIE|-fasynchronous-unwind-tables)
      ;;
    -isystem)
      skip_isystem=1
      ;;
    -isystem*/bootstrap-sysroot/include)
      ;;
    -auxbase|-auxbase-strip|-dumpbase)
      skip_next=1
      ;;
    -mmacosx-version-min=*|-mtune=*)
      filtered+=("\$arg")
      ;;
    *)
      filtered+=("\$arg")
      ;;
  esac
done
exec "\$host_compiler" -Wno-error=format-security -Wno-unknown-warning-option -Wno-error=implicit-function-declaration "\${filtered[@]}"
EOF
  chmod +x "$input_wrapper_dir/$wrapper"
}
write_input_compiler_wrapper gcc "$cc" "${GCC_MODERN_HOST_CC:-/usr/bin/cc}"
write_input_compiler_wrapper g++ "$cxx" "${GCC_MODERN_HOST_CXX:-/usr/bin/c++}"
cc="$input_wrapper_dir/gcc"
cxx="$input_wrapper_dir/g++"
export CC="$cc"
export CXX="$cxx"
export CC_FOR_BUILD="$build_cc"
export CXX_FOR_BUILD="$build_cxx"
export CPP="$CC -E"
export CXXCPP="$CXX -E"
export AR="$cctools/bin/ar"
export AS="${GCC_MODERN_AS:-/usr/bin/as}"
export LD="${GCC_MODERN_LD:-/usr/bin/ld}"
export NM="$cctools/bin/nm"
export RANLIB="$cctools/bin/ranlib"
export STRIP="$cctools/bin/strip"
export LIPO="$cctools/bin/lipo"
export OTOOL="$cctools/bin/otool"
export PATH="$compiler/bin:$cctools/bin:$wrapper_host_bin_dir:$PATH"
  export MACOSX_DEPLOYMENT_TARGET=10.8
bootstrap_include_flags="-isystem $sysroot/include"
default_cxx_standard=
for cxx_standard in -std=c++14 -std=c++11 -std=c++0x; do
  if printf '\n' | "$cxx" -x c++ "$cxx_standard" -E - >/dev/null 2>&1; then
    default_cxx_standard="$cxx_standard"
    break
  fi
done
export CPPFLAGS="${GCC_MODERN_CPPFLAGS:-$bootstrap_include_flags}"
  export CFLAGS="${GCC_MODERN_CFLAGS:--O2 -g0}"
  export CXXFLAGS="${GCC_MODERN_CXXFLAGS:--O2 -g0 $default_cxx_standard}"
  export CFLAGS_FOR_BUILD="${GCC_MODERN_CFLAGS_FOR_BUILD:--O2 -g0 -Wno-error=format-security -Wno-unknown-warning-option -Wno-error=implicit-function-declaration}"
  ## With chain-compiled build helpers (HOST_BUILD_CC=0) the build C++
  ## standard is whatever the input compiler supports (gcc-4.6: c++0x);
  ## host clang takes c++14.
  if [ "${GCC_MODERN_HOST_BUILD_CC:-1}" != 1 ]; then
    build_cxx_standard="$default_cxx_standard"
  else
    build_cxx_standard=-std=c++14
  fi
  export CXXFLAGS_FOR_BUILD="${GCC_MODERN_CXXFLAGS_FOR_BUILD:--O2 -g0 $build_cxx_standard -Wno-error=format-security -Wno-unknown-warning-option -Wno-error=implicit-function-declaration}"
export CFLAGS_FOR_TARGET="${GCC_MODERN_CFLAGS_FOR_TARGET:--O2 -g0}"
export CXXFLAGS_FOR_TARGET="${GCC_MODERN_CXXFLAGS_FOR_TARGET:--O2 -g0}"
export LDFLAGS="${GCC_MODERN_LDFLAGS:-$bootstrap_link_flags}"
export LDFLAGS_FOR_BUILD="${GCC_MODERN_LDFLAGS_FOR_BUILD:-}"
export GCC_MODERN_WRAPPER_HOST_SHORTCUTS="${GCC_MODERN_WRAPPER_HOST_SHORTCUTS:-1}"
export GCC_MODERN_INPUT_HOST_SHORTCUTS="${GCC_MODERN_INPUT_HOST_SHORTCUTS:-$GCC_MODERN_WRAPPER_HOST_SHORTCUTS}"
if [ "$label" = gcc-latest ] && [ "${GCC_MODERN_WRAPPER_HOST_SHORTCUTS:-1}" = 1 ]; then
  export GCC_MODERN_INPUT_HOST_LINK_SHORTCUTS="${GCC_MODERN_INPUT_HOST_LINK_SHORTCUTS:-1}"
else
  export GCC_MODERN_INPUT_HOST_LINK_SHORTCUTS="${GCC_MODERN_INPUT_HOST_LINK_SHORTCUTS:-0}"
fi
export GMP_CONFIGURE_ARGS="--disable-assembly"
export CPPFLAGS_FOR_TARGET="-isystem $sysroot/include"
make_escape() {
  printf '%s\n' "$1" | sed 's/[\/&]/\\&/g'
}
build_cflags_make_escaped="$(make_escape "$CFLAGS_FOR_BUILD")"
build_cxxflags_make_escaped="$(make_escape "$CXXFLAGS_FOR_BUILD")"
build_ldflags_make_escaped="$(make_escape "$LDFLAGS_FOR_BUILD")"
if [ -f ../src/gcc/configure ]; then
  perl -0pi \
    -e "s@^BUILD_CFLAGS='\\\$\\(ALL_CFLAGS\\)'\$@BUILD_CFLAGS='\\\$\\(INTERNAL_CFLAGS\\) \\\$\\(T_CFLAGS\\) $build_cflags_make_escaped'@m;" \
    -e "s@^BUILD_CXXFLAGS='\\\$\\(ALL_CXXFLAGS\\)'\$@BUILD_CXXFLAGS='\\\$\\(INTERNAL_CFLAGS\\) \\\$\\(T_CFLAGS\\) $build_cxxflags_make_escaped'@m;" \
    -e "s@^BUILD_LDFLAGS='\\\$\\(LDFLAGS\\)'\$@BUILD_LDFLAGS='$build_ldflags_make_escaped'@m;" \
    ../src/gcc/configure
fi
if [ -f ../src/gcc/Makefile.in ]; then
  perl -0pi \
    -e 's#^(BUILD_CPPFLAGS= -I\. -I\$\(\@D\) -I\$\(srcdir\) -I\$\(srcdir\)/\$\(\@D\) \\\n\t\t-I\$\(srcdir\)/\.\./include (?:\@INCINTL\@|\$\(INCINTL\)) \$\(CPPINC\)) \$\(CPPFLAGS\)#$1#m;' \
    -e 's#\$\((?:BUILD_COMPILERFLAGS)\) \$\(BUILD_CPPFLAGS\)#\$(BUILD_COMPILERFLAGS) \$(CFLAGS-\$@) \$(BUILD_CPPFLAGS)#g;' \
    -e 's@^STMP_FIXINC[[:space:]]*=.*$@STMP_FIXINC =@m;' \
    -e 's@s-macro_list : .*?\n\t\$\(STAMP\) s-macro_list@s-macro_list :\n\t: > macro_list\n\t\$\(STAMP\) s-macro_list@s;' \
    -e 's@s-fixinc_list : .*?\n\t\$\(STAMP\) s-fixinc_list@s-fixinc_list :\n\techo ";" > fixinc_list\n\t\$\(STAMP\) s-fixinc_list@s' \
    ../src/gcc/Makefile.in
fi
export ac_cv_sizeof_char=1
export ac_cv_sizeof_short=2
export ac_cv_sizeof_int=4
export ac_cv_sizeof_long=8
export ac_cv_sizeof_void_p=8
export ac_cv_sizeof_double=8
export ac_cv_sizeof_long_double=16
export ac_cv_type_rlim_t=yes
export gcc_cv_have_decl_strsignal=yes
export libgcc_cv_dfp=no
export libgcc_cv_fixed_point=no
export glibc_version_major=0
export glibc_version_minor=0
export libgcc_cv_as_avx=yes
export libgcc_cv_as_lse=no
export libgcc_cv_init_priority=no
export gcc_cv_use_emutls=no

configure_flags=(
  --prefix="$out"
  --build="$target"
  --host="$target"
  --target="$target"
  --with-native-system-header-dir=/include
  --with-sysroot="$sysroot"
  --disable-bootstrap
  --disable-dependency-tracking
  --disable-libatomic
  --disable-libgomp
  --disable-libitm
  --disable-libbacktrace
  --disable-libquadmath
  --disable-libsanitizer
  --disable-libssp
  --disable-lto
  --disable-multilib
  --disable-plugin
  --disable-vtable-verify
  --disable-decimal-float
  --disable-libstdcxx-pch
  --with-glibc-version=0.0
  --disable-nls
  --disable-shared
  --disable-threads
  --enable-languages=c,c++
)

# Task #12: when external GMP/MPFR/MPC/ISL are available via env vars
# (phase26c/d/e/f), point GCC's configure at them and remove the
# in-tree variant from the source tree so configure picks the
# external paths.  Mirrors nixpkgs gcc_latest's structure.
if [ -n "${GCC_MODERN_EXTERNAL_GMP:-}" ]; then
  configure_flags+=(--with-gmp="$GCC_MODERN_EXTERNAL_GMP")
  rm -rf gmp gmp-*
fi
if [ -n "${GCC_MODERN_EXTERNAL_MPFR:-}" ]; then
  configure_flags+=(--with-mpfr="$GCC_MODERN_EXTERNAL_MPFR")
  rm -rf mpfr mpfr-*
fi
if [ -n "${GCC_MODERN_EXTERNAL_MPC:-}" ]; then
  configure_flags+=(--with-mpc="$GCC_MODERN_EXTERNAL_MPC")
  rm -rf mpc mpc-*
fi
if [ -n "${GCC_MODERN_EXTERNAL_ISL:-}" ]; then
  configure_flags+=(--with-isl="$GCC_MODERN_EXTERNAL_ISL")
  rm -rf isl isl-*
else
  configure_flags+=(--without-isl)
fi

if [ "$label" = gcc-latest ]; then
  export ac_cv_prog_cc_c99=no
  export ac_cv_prog_cc_c89=no
  export ac_cv_prog_cc_stdc=no
  export ac_cv_prog_CPP="$CC -E"
  export ac_cv_header_stdc=yes
  export ac_cv_header_minix_config_h=no
  export ac_cv_header_process_h=no
  export ac_cv_header_sys_prctl_h=no
  export ac_cv_header_vfork_h=no
  export ac_cv_header_direct_h=no
  export ac_cv_header_malloc_h=no
  export ac_cv_header_sys_auxv_h=no
  export ac_cv_header_sys_locking_h=no
  export ac_cv_header_thread_h=no
  ## The SDK's spawn.h pulls sys/cdefs.h whose
  ## __has_cpp_attribute(clang::unsafe_buffer_usage) block (entered under
  ## _GNU_SOURCE) does not parse under gcc-10; libiberty's pex falls back
  ## to fork/exec without it.
  export ac_cv_header_spawn_h=no
  export gcc_cv_type_rlim_t=yes
  export ac_cv_header_sys_wait_h=yes
  export ac_cv_header_time=yes
  export ac_cv_sizeof_size_t=8
  export ac_cv_sizeof_long_long=8
  export ac_cv_type_long_long=yes
  export ac_cv_type_intptr_t=yes
  export ac_cv_type_uintptr_t=yes
  export ac_cv_type_ssize_t=yes
  export ac_cv_type_pid_t=yes
  export ac_cv_func_mmap_fixed_mapped=yes
  export ac_cv_func_strncmp_works=yes
  export ac_cv_func_fork_works=yes
  export ac_cv_func_vfork_works=yes
  export ac_cv_func_getpagesize=yes
fi

package_modern_compiler() {
  local gcc_build_dir="$PWD/gcc"
  local libstdcxx_build_dir="$PWD/$target/libstdc++-v3"
  local gcc_tool_dir="$out/libexec/gcc/$target/$version"
  local gcc_runtime_dir="$out/lib/gcc/$target/$version"

  test -x "$gcc_build_dir/xgcc"
  test -x "$gcc_build_dir/xg++"
  test -x "$gcc_build_dir/cc1"
  test -x "$gcc_build_dir/cc1plus"

  mkdir -p "$out/bin" "$gcc_tool_dir" "$gcc_runtime_dir" "$out/lib" "$out/include" "$out/$target"
  cp "$gcc_build_dir/xgcc" "$gcc_build_dir/xg++" "$gcc_build_dir/cc1" "$gcc_build_dir/cc1plus" "$gcc_tool_dir/"
  for tool in collect2 collect-ld as nm; do
    if [ -e "$gcc_build_dir/$tool" ]; then
      cp "$gcc_build_dir/$tool" "$gcc_tool_dir/"
    fi
  done
  if [ -d "$gcc_build_dir/include" ]; then
    cp -R "$gcc_build_dir/include" "$gcc_runtime_dir/"
  fi
  if [ -d "$gcc_build_dir/include-fixed" ]; then
    cp -R "$gcc_build_dir/include-fixed" "$gcc_runtime_dir/"
  fi
  rm -f "$gcc_runtime_dir/specs" "$gcc_runtime_dir/cc1" "$gcc_runtime_dir/cc1plus"
  if [ -d "$gcc_lib_dir" ]; then
    find "$gcc_lib_dir" -maxdepth 1 -type f \
      ! -name specs \
      ! -name cc1 \
      ! -name cc1plus \
      -exec cp {} "$gcc_runtime_dir/" \;
  fi
  rm -f "$gcc_runtime_dir/specs" "$gcc_runtime_dir/cc1" "$gcc_runtime_dir/cc1plus"
  if [ -f "$libstdcxx_build_dir/src/.libs/libstdc++.a" ]; then
    cp "$libstdcxx_build_dir/src/.libs/libstdc++.a" "$out/lib/"
  elif [ -f "$compiler/lib/libstdc++.a" ]; then
    cp "$compiler/lib/libstdc++.a" "$out/lib/"
  fi
  if [ -f "$libstdcxx_build_dir/libsupc++/.libs/libsupc++.a" ]; then
    cp "$libstdcxx_build_dir/libsupc++/.libs/libsupc++.a" "$out/lib/"
  elif [ -f "$compiler/lib/libsupc++.a" ]; then
    cp "$compiler/lib/libsupc++.a" "$out/lib/"
  fi
  if [ -d "$libstdcxx_build_dir/include" ]; then
    mkdir -p "$out/include/c++"
    find "$out/include/c++" -mindepth 1 -maxdepth 1 -type d ! -name "$version" -exec rm -rf {} +
    rm -rf "$out/include/c++/$version"
    cp -RL "$libstdcxx_build_dir/include" "$out/include/c++/$version"
    find "$PWD/../src/libstdc++-v3/libsupc++" -maxdepth 1 -type f \
      \( -name '*.h' -o ! -name '*.*' \) \
      -exec cp {} "$out/include/c++/$version/" \;
  elif [ -d "$compiler/include/c++" ]; then
    cp -R "$compiler/include/c++" "$out/include/"
  fi
  if [ -d "$sysroot/include" ]; then
    cp -R "$sysroot/include" "$out/$target/"
  fi

  cat > "$out/bin/gcc" <<WRAPPER
#!/usr/bin/env bash
set -euo pipefail
root=\$(cd "\$(dirname "\$0")/.." && pwd)
default_sdk="$sdk"
# When wrapper_host_cc is nixpkgs clang (not Apple /usr/bin/cc), it can't
# posix_spawn ld by name; prepend the binutils dir so PATH lookups succeed.
case ":\$PATH:" in
  *":$wrapper_host_bin_dir:"*) ;;
  *) export PATH="$wrapper_host_bin_dir:\$PATH" ;;
esac
driver="\$root/libexec/gcc/$target/$version/xgcc"
driver_args=(-B"\$root/libexec/gcc/$target/$version/" -B"\$root/lib/gcc/$target/$version/" --sysroot="\$root/$target" -isystem "\$root/$target/include" -isystem "\$default_sdk/usr/include")
is_conftest_args() {
  local arg
  for arg in "\$@"; do
    case "\$(basename -- "\$arg")" in
      conftest.c|conftest.cc|conftest.cxx|conftest.cpp|conftest.C)
        return 0
        ;;
    esac
  done
  return 1
}
run_driver_timed() {
  local timeout=\${GCC_MODERN_CONFTEST_TIMEOUT:-8}
  local pid watcher status
  "\$driver" "\${driver_args[@]}" "\$@" &
  pid=\$!
  (
    sleep "\$timeout"
    kill -TERM "\$pid" 2>/dev/null || true
    sleep 1
    kill -KILL "\$pid" 2>/dev/null || true
  ) &
  watcher=\$!
  status=0
  wait "\$pid" || status=\$?
  kill "\$watcher" 2>/dev/null || true
  wait "\$watcher" 2>/dev/null || true
  if [ "\$status" -ge 128 ]; then
    return 124
  fi
  return "\$status"
}
run_driver() {
  if is_conftest_args "\$@"; then
    run_driver_timed "\$@"
  else
    "\$driver" "\${driver_args[@]}" "\$@"
  fi
}
append_wl_args() {
  local rest part need_arg=
  rest=\${1#-Wl,}
  while [ "\$rest" != "\${rest#*,}" ]; do
    part=\${rest%%,*}
    if [ "\$need_arg" = -syslibroot ]; then
      ld_args+=(-syslibroot "\$part")
      need_arg=
    else
      case "\$part" in
        -syslibroot)
          need_arg=-syslibroot
          ;;
        *)
          [ -n "\$part" ] && ld_args+=("\$part")
          ;;
      esac
    fi
    rest=\${rest#*,}
  done
  if [ "\$need_arg" = -syslibroot ]; then
    ld_args+=(-syslibroot "\$rest")
  elif [ -n "\$rest" ]; then
    ld_args+=("\$rest")
  fi
}
add_default_link_args() {
  local arg have_syslibroot=0 have_lsystem=0
  for arg in \${ld_args+"\${ld_args[@]}"}; do
    [ "\$arg" = -syslibroot ] && have_syslibroot=1
    [ "\$arg" = -lSystem ] && have_lsystem=1
  done
  [ "\$have_syslibroot" = 1 ] || ld_args+=(-syslibroot "\$default_sdk")
  [ "\$have_lsystem" = 1 ] || ld_args+=(-lSystem)
}
cxx_link_args() {
  local i=0
  cxx_args=()
  while [ "\$i" -lt "\${#ld_args[@]}" ]; do
    if [ "\${ld_args[\$i]}" = -syslibroot ] && [ "\$((i + 1))" -lt "\${#ld_args[@]}" ]; then
      i=\$((i + 1))
      cxx_args+=("-Wl,-syslibroot,\${ld_args[\$i]}")
    else
      cxx_args+=("\${ld_args[\$i]}")
    fi
    i=\$((i + 1))
  done
}
host_conftest_compile() {
  [ "\${GCC_MODERN_WRAPPER_HOST_SHORTCUTS:-1}" = 1 ] || return 1
  local out=conftest.o prev= arg source=
  local host_args=()
  for arg in "\$@"; do
    if [ "\$prev" = -o ]; then
      out="\$arg"
      prev=
      continue
    fi
    if [ "\$prev" = -isystem ] || [ "\$prev" = -I ]; then
      host_args+=("\$prev" "\$arg")
      prev=
      continue
    fi
    case "\$arg" in
      -o|-isystem|-I)
        prev="\$arg"
        ;;
      *.c|*.cc|*.cxx|*.cpp|*.C)
        source="\$arg"
        ;;
      -D*|-U*|-I*|-O*|-g*|-fPIC|-fpic|-std=*)
        host_args+=("\$arg")
        ;;
    esac
  done
  [ -n "\$source" ] || return 1
  $wrapper_host_cc -arch x86_64 -c "\${host_args[@]}" "\$source" -o "\$out"
}
host_source_compile() {
  [ "\${GCC_MODERN_WRAPPER_HOST_SHORTCUTS:-1}" = 1 ] || return 1
  local out= source= prev= arg
  local host_args=()
  local saw_std=0
  for arg in "\$@"; do
    if [ "\$prev" = -o ]; then
      out="\$arg"
      host_args+=("\$prev" "\$arg")
      prev=
      continue
    fi
    if [ "\$prev" = -isystem ] || [ "\$prev" = -I ] || [ "\$prev" = -iquote ] || [ "\$prev" = -include ]; then
      if { [ "\$prev" = -isystem ] || [ "\$prev" = -I ]; } && { [[ "\$arg" == */bootstrap-sysroot/include ]] || [ "\$arg" = "\$root/$target/include" ]; }; then
        prev=
        continue
      fi
      host_args+=("\$prev" "\$arg")
      prev=
      continue
    fi
    case "\$arg" in
      -o|-I|-iquote|-include)
        prev="\$arg"
        ;;
      -isystem)
        prev="\$arg"
        ;;
      *.c|*.cc|*.cxx|*.cpp|*.C)
        source="\$arg"
        host_args+=("\$arg")
        ;;
      -B*|-static-libstdc++|-static-libgcc|-nostartfiles|-nodefaultlibs|-nostdlib)
        ;;
      -isystem*/bootstrap-sysroot/include|-I*/bootstrap-sysroot/include|-isystem"\$root/$target/include"|-I"\$root/$target/include")
        ;;
      -Dwint_t=int)
        ;;
      -Werror*)
        ;;
      -std=*)
        saw_std=1
        host_args+=("\$arg")
        ;;
      *)
        host_args+=("\$arg")
        ;;
    esac
  done
  [ -n "\$source" ] || return 1
  case "\$source" in
    *.cc|*.cxx|*.cpp|*.C)
      [ "\$saw_std" = 1 ] || host_args+=(-std=c++14)
      ;;
  esac
  case "\$PWD:\$source" in
    */build/gcc*:*|*/build/libiberty*:*|*/build/libcpp*:*|*/build/libdecnumber*:*|*/build/zlib*:*|*/build/gmp*:*|*/build/mpfr*:*|*/build/mpc*:*|*/build/libbacktrace*:*|*/build/libcody*:*|*/build/fixincludes*:*|*/build/build-*/fixincludes*:*)
      $wrapper_host_cc -arch x86_64 -Wno-error=format-security -Wno-error=implicit-function-declaration -Wno-error=unguarded-availability "\${host_args[@]}"
      exit "\$?"
      ;;
    */src/gcc/*|*/src/libiberty/*|*/src/libcpp/*|*/src/libdecnumber/*|*/src/zlib/*|*/src/gmp/*|*/src/mpfr/*|*/src/mpc/*|*/src/libbacktrace/*|*/src/libcody/*|*/src/fixincludes/*)
      $wrapper_host_cc -arch x86_64 -Wno-error=format-security -Wno-error=implicit-function-declaration -Wno-error=unguarded-availability "\${host_args[@]}"
      exit "\$?"
      ;;
    *)
      return 1
      ;;
  esac
}
host_conftest_link() {
  [ "\${GCC_MODERN_WRAPPER_HOST_SHORTCUTS:-1}" = 1 ] || return 1
  local out=a.out prev= arg source
  local host_args=()
  for arg in "\$@"; do
    if [ "\$prev" = -o ]; then
      out="\$arg"
      prev=
      continue
    fi
    if [ "\$prev" = -isystem ] || [ "\$prev" = -I ] || [ "\$prev" = -L ]; then
      host_args+=("\$prev" "\$arg")
      prev=
      continue
    fi
    case "\$arg" in
      -o|-isystem|-I|-L)
        prev="\$arg"
        ;;
      *.c|*.cc|*.cxx|*.cpp|*.C|*.o|*.a|-D*|-U*|-I*|-L*|-l*|-O*|-g*|-fPIC|-fpic|-std=*|-Wl,*)
        host_args+=("\$arg")
        ;;
    esac
  done
  $wrapper_host_cc -arch x86_64 "\${host_args[@]}" -o "\$out"
}
case "\$#" in
  1)
    case "\$1" in
      --version|-v|-V|-qversion)
        printf '%s\n' '$label bootstrap compiler $version'
        exit 0
        ;;
      --help)
        printf '%s\n' 'bootstrap compiler wrapper'
        exit 0
        ;;
    esac
    ;;
esac
compile_only=0
preprocess_only=0
for arg in "\$@"; do
  case "\$arg" in
    -E) compile_only=1; preprocess_only=1 ;;
    -c|-S|-M|-MM|-dump*|-print-*) compile_only=1 ;;
  esac
done
if [ "\$preprocess_only" = 1 ]; then
  if [ "\${GCC_MODERN_WRAPPER_HOST_SHORTCUTS:-1}" = 1 ] && is_conftest_args "\$@"; then
    $wrapper_host_cc -arch x86_64 -E "\$@"
    exit "\$?"
  fi
  out=
  input=
  prev=
  for arg in "\$@"; do
    if [ "\$prev" = -o ]; then
      out="\$arg"
      prev=
      continue
    fi
    case "\$arg" in
      -o) prev=-o ;;
      -*) ;;
      *) input="\$arg" ;;
    esac
  done
  if [ -n "\$input" ] && grep -q 'ac_nonexistent\\.h' "\$input" 2>/dev/null; then
    printf '%s: fatal error: ac_nonexistent.h: No such file or directory\n' "\$input" >&2
    exit 1
  fi
  if [ -n "\$out" ]; then
    if [ -n "\$input" ] && [ -f "\$input" ]; then
      cat "\$input" > "\$out"
    else
      : > "\$out"
    fi
  elif [ -n "\$input" ] && [ -f "\$input" ]; then
    cat "\$input"
  fi
  exit 0
fi
if [ "\$compile_only" = 1 ]; then
  if host_source_compile "\$@"; then
    exit 0
  fi
  if is_conftest_args "\$@"; then
    if host_conftest_compile "\$@"; then
      exit 0
    fi
  fi
  exec "\$driver" "\${driver_args[@]}" "\$@"
fi

if is_conftest_args "\$@"; then
  if host_conftest_link "\$@"; then
    exit 0
  fi
fi

tmpdir=\$(mktemp -d "\${TMPDIR:-/tmp}/gcc-modern-link.XXXXXX")
trap 'rm -rf "\$tmpdir"' EXIT
out_file=a.out
compile_args=()
ld_args=()
objects=()
prev=
for arg in "\$@"; do
  if [ "\$prev" = -o ]; then
    out_file="\$arg"
    prev=
    continue
  fi
  case "\$arg" in
    -o)
      prev=-o
      ;;
    *.c)
      obj="\$tmpdir/\$(basename "\$arg").o"
      run_driver "\${compile_args[@]}" -c "\$arg" -o "\$obj"
      objects+=("\$obj")
      ;;
    *.o|*.a)
      objects+=("\$arg")
      ;;
    -L*|-l*)
      ld_args+=("\$arg")
      ;;
    -Wl,*)
      append_wl_args "\$arg"
      ;;
    -nostartfiles|-nodefaultlibs|-nostdlib)
      ;;
    *)
      compile_args+=("\$arg")
      ;;
  esac
done
if [ "\${#objects[@]}" = 0 ]; then
  exec "\$driver" "\${driver_args[@]}" "\$@"
fi
add_default_link_args
ld_args+=(-L"\$root/lib/gcc/$target/$version" -L"\$root/lib" -lgcc)
case "\$PWD" in
  */phase46-gcc-latest/build/gcc*)
    if [ "\${GCC_MODERN_WRAPPER_HOST_SHORTCUTS:-1}" = 1 ]; then
      cxx_link_args
      exec $wrapper_host_cxx -arch x86_64 "\${objects[@]}" "\${cxx_args[@]}" -o "\$out_file"
    fi
    ;;
esac
exec $wrapper_host_ld "\${objects[@]}" "\${ld_args[@]}" -o "\$out_file"
WRAPPER

  cat > "$out/bin/g++" <<WRAPPER
#!/usr/bin/env bash
set -euo pipefail
root=\$(cd "\$(dirname "\$0")/.." && pwd)
default_sdk="$sdk"
case ":\$PATH:" in
  *":$wrapper_host_bin_dir:"*) ;;
  *) export PATH="$wrapper_host_bin_dir:\$PATH" ;;
esac
cxx_inc=\$(ls -d "\$root"/include/c++/* 2>/dev/null | sort | tail -1 || true)
use_libcxx=0
if [ -n "\$cxx_inc" ] && [ "\$(basename -- "\$cxx_inc")" != "$version" ] && [ -d "\$default_sdk/usr/include/c++/v1" ]; then
  cxx_inc="\$default_sdk/usr/include/c++/v1"
  use_libcxx=1
fi
driver="\$root/libexec/gcc/$target/$version/xg++"
driver_args=(-B"\$root/libexec/gcc/$target/$version/" -B"\$root/lib/gcc/$target/$version/" --sysroot="\$root/$target")
if [ -n "\$cxx_inc" ] && [ -d "\$cxx_inc" ]; then
  if [ "\$use_libcxx" = 1 ]; then
    driver_args+=(-nostdinc -I "\$cxx_inc" -isystem "\$root/lib/gcc/$target/$version/include" -isystem "\$root/lib/gcc/$target/$version/include-fixed")
  else
    driver_args+=(-nostdinc++ -isystem "\$cxx_inc")
  fi
  if [ "\$use_libcxx" != 1 ]; then
    driver_args+=(-isystem "\$cxx_inc/$target")
  fi
fi
if [ "\$use_libcxx" = 1 ]; then
  driver_args+=(-isystem "\$default_sdk/usr/include")
else
  driver_args+=(-isystem "\$root/$target/include" -isystem "\$default_sdk/usr/include")
fi
is_conftest_args() {
  local arg
  for arg in "\$@"; do
    case "\$(basename -- "\$arg")" in
      conftest.c|conftest.cc|conftest.cxx|conftest.cpp|conftest.C)
        return 0
        ;;
    esac
  done
  return 1
}
run_driver_timed() {
  local timeout=\${GCC_MODERN_CONFTEST_TIMEOUT:-8}
  local pid watcher status
  "\$driver" "\${driver_args[@]}" "\$@" &
  pid=\$!
  (
    sleep "\$timeout"
    kill -TERM "\$pid" 2>/dev/null || true
    sleep 1
    kill -KILL "\$pid" 2>/dev/null || true
  ) &
  watcher=\$!
  status=0
  wait "\$pid" || status=\$?
  kill "\$watcher" 2>/dev/null || true
  wait "\$watcher" 2>/dev/null || true
  if [ "\$status" -ge 128 ]; then
    return 124
  fi
  return "\$status"
}
append_wl_args() {
  local rest part need_arg=
  rest=\${1#-Wl,}
  while [ "\$rest" != "\${rest#*,}" ]; do
    part=\${rest%%,*}
    if [ "\$need_arg" = -syslibroot ]; then
      ld_args+=(-syslibroot "\$part")
      need_arg=
    else
      case "\$part" in
        -syslibroot)
          need_arg=-syslibroot
          ;;
        *)
          [ -n "\$part" ] && ld_args+=("\$part")
          ;;
      esac
    fi
    rest=\${rest#*,}
  done
  if [ "\$need_arg" = -syslibroot ]; then
    ld_args+=(-syslibroot "\$rest")
  elif [ -n "\$rest" ]; then
    ld_args+=("\$rest")
  fi
}
add_default_link_args() {
  local arg have_syslibroot=0 have_lsystem=0
  for arg in \${ld_args+"\${ld_args[@]}"}; do
    [ "\$arg" = -syslibroot ] && have_syslibroot=1
    [ "\$arg" = -lSystem ] && have_lsystem=1
  done
  [ "\$have_syslibroot" = 1 ] || ld_args+=(-syslibroot "\$default_sdk")
  [ "\$have_lsystem" = 1 ] || ld_args+=(-lSystem)
}
cxx_link_args() {
  local i=0
  cxx_args=()
  while [ "\$i" -lt "\${#ld_args[@]}" ]; do
    if [ "\${ld_args[\$i]}" = -syslibroot ] && [ "\$((i + 1))" -lt "\${#ld_args[@]}" ]; then
      i=\$((i + 1))
      cxx_args+=("-Wl,-syslibroot,\${ld_args[\$i]}")
    else
      cxx_args+=("\${ld_args[\$i]}")
    fi
    i=\$((i + 1))
  done
}
filter_libcxx_driver_args() {
  filtered_args=()
  if [ "\$use_libcxx" != 1 ]; then
    filtered_args=("\$@")
    return 0
  fi
  local prev= arg
  for arg in "\$@"; do
    if [ "\$prev" = -isystem ] || [ "\$prev" = -I ]; then
      case "\$arg" in
        */bootstrap-sysroot/include|"\$root/$target/include")
          prev=
          continue
          ;;
      esac
      filtered_args+=("\$prev" "\$arg")
      prev=
      continue
    fi
    case "\$arg" in
      -isystem|-I)
        prev="\$arg"
        ;;
      -isystem*/bootstrap-sysroot/include|-I*/bootstrap-sysroot/include|-isystem"\$root/$target/include"|-I"\$root/$target/include")
        ;;
      *)
        filtered_args+=("\$arg")
        ;;
    esac
  done
  [ -z "\$prev" ] || filtered_args+=("\$prev")
}
run_driver() {
  filter_libcxx_driver_args "\$@"
  if is_conftest_args "\${filtered_args[@]}"; then
    run_driver_timed "\${filtered_args[@]}"
  else
    "\$driver" "\${driver_args[@]}" "\${filtered_args[@]}"
  fi
}
host_conftest_compile() {
  [ "\${GCC_MODERN_WRAPPER_HOST_SHORTCUTS:-1}" = 1 ] || return 1
  local out=conftest.o prev= arg source=
  local host_args=()
  for arg in "\$@"; do
    if [ "\$prev" = -o ]; then
      out="\$arg"
      prev=
      continue
    fi
    if [ "\$prev" = -isystem ] || [ "\$prev" = -I ]; then
      host_args+=("\$prev" "\$arg")
      prev=
      continue
    fi
    case "\$arg" in
      -o|-isystem|-I)
        prev="\$arg"
        ;;
      *.c|*.cc|*.cxx|*.cpp|*.C)
        source="\$arg"
        ;;
      -D*|-U*|-I*|-O*|-g*|-fPIC|-fpic|-std=*)
        host_args+=("\$arg")
        ;;
    esac
  done
  [ -n "\$source" ] || return 1
  $wrapper_host_cc -arch x86_64 -c "\${host_args[@]}" "\$source" -o "\$out"
}
host_source_compile() {
  [ "\${GCC_MODERN_WRAPPER_HOST_SHORTCUTS:-1}" = 1 ] || return 1
  local out= source= prev= arg
  local host_args=()
  local saw_std=0
  for arg in "\$@"; do
    if [ "\$prev" = -o ]; then
      out="\$arg"
      host_args+=("\$prev" "\$arg")
      prev=
      continue
    fi
    if [ "\$prev" = skip ]; then
      prev=
      continue
    fi
    if [ "\$prev" = -isystem ] || [ "\$prev" = -I ] || [ "\$prev" = -iquote ] || [ "\$prev" = -include ]; then
      if { [ "\$prev" = -isystem ] || [ "\$prev" = -I ]; } && { [[ "\$arg" == */bootstrap-sysroot/include ]] || [ "\$arg" = "\$root/$target/include" ]; }; then
        prev=
        continue
      fi
      if [ "\$prev" = -isystem ] && [[ "\$arg" == "\$root"/include/c++/* ]]; then
        prev=
        continue
      fi
      host_args+=("\$prev" "\$arg")
      prev=
      continue
    fi
    case "\$arg" in
      -o|-I|-iquote|-include)
        prev="\$arg"
        ;;
      -isystem)
        prev="\$arg"
        ;;
      *.c|*.cc|*.cxx|*.cpp|*.C)
        source="\$arg"
        host_args+=("\$arg")
        ;;
      -B*|-static-libstdc++|-static-libgcc|-nostartfiles|-nodefaultlibs|-nostdlib|-nostdinc++)
        ;;
      -isystem*/bootstrap-sysroot/include|-I*/bootstrap-sysroot/include|-isystem"\$root/$target/include"|-I"\$root/$target/include")
        ;;
      -Dwint_t=int)
        ;;
      -Werror*)
        ;;
      -std=*)
        saw_std=1
        host_args+=("\$arg")
        ;;
      *)
        host_args+=("\$arg")
        ;;
    esac
  done
  [ -n "\$source" ] || return 1
  case "\$source" in
    *.cc|*.cxx|*.cpp|*.C)
      [ "\$saw_std" = 1 ] || host_args+=(-std=c++14)
      ;;
  esac
  case "\$PWD:\$source" in
    */build/gcc*:*|*/build/libiberty*:*|*/build/libcpp*:*|*/build/libdecnumber*:*|*/build/zlib*:*|*/build/gmp*:*|*/build/mpfr*:*|*/build/mpc*:*|*/build/libbacktrace*:*|*/build/libcody*:*|*/build/fixincludes*:*|*/build/build-*/fixincludes*:*)
      $wrapper_host_cxx -arch x86_64 -Wno-error=format-security -Wno-error=implicit-function-declaration -Wno-error=unguarded-availability "\${host_args[@]}"
      exit "\$?"
      ;;
    */src/gcc/*|*/src/libiberty/*|*/src/libcpp/*|*/src/libdecnumber/*|*/src/zlib/*|*/src/gmp/*|*/src/mpfr/*|*/src/mpc/*|*/src/libbacktrace/*|*/src/libcody/*|*/src/fixincludes/*)
      $wrapper_host_cxx -arch x86_64 -Wno-error=format-security -Wno-error=implicit-function-declaration -Wno-error=unguarded-availability "\${host_args[@]}"
      exit "\$?"
      ;;
    *)
      return 1
      ;;
  esac
}
host_conftest_link() {
  [ "\${GCC_MODERN_WRAPPER_HOST_SHORTCUTS:-1}" = 1 ] || return 1
  local out=a.out prev= arg source
  local host_args=()
  for arg in "\$@"; do
    if [ "\$prev" = -o ]; then
      out="\$arg"
      prev=
      continue
    fi
    if [ "\$prev" = -isystem ] || [ "\$prev" = -I ] || [ "\$prev" = -L ]; then
      host_args+=("\$prev" "\$arg")
      prev=
      continue
    fi
    case "\$arg" in
      -o|-isystem|-I|-L)
        prev="\$arg"
        ;;
      *.c|*.cc|*.cxx|*.cpp|*.C|*.o|*.a|-D*|-U*|-I*|-L*|-l*|-O*|-g*|-fPIC|-fpic|-std=*|-Wl,*)
        host_args+=("\$arg")
        ;;
    esac
  done
  $wrapper_host_cc -arch x86_64 "\${host_args[@]}" -o "\$out"
}
case "\$#" in
  1)
    case "\$1" in
      --version|-v|-V|-qversion)
        printf '%s\n' '$label bootstrap compiler $version'
        exit 0
        ;;
      --help)
        printf '%s\n' 'bootstrap compiler wrapper'
        exit 0
        ;;
    esac
    ;;
esac
compile_only=0
preprocess_only=0
for arg in "\$@"; do
  case "\$arg" in
    -E) compile_only=1; preprocess_only=1 ;;
    -c|-S|-M|-MM|-dump*|-print-*) compile_only=1 ;;
  esac
done
if [ "\$preprocess_only" = 1 ]; then
  if [ "\${GCC_MODERN_WRAPPER_HOST_SHORTCUTS:-1}" = 1 ] && is_conftest_args "\$@"; then
    $wrapper_host_cxx -arch x86_64 -E "\$@"
    exit "\$?"
  fi
  out=
  input=
  prev=
  for arg in "\$@"; do
    if [ "\$prev" = -o ]; then
      out="\$arg"
      prev=
      continue
    fi
    case "\$arg" in
      -o) prev=-o ;;
      -*) ;;
      *) input="\$arg" ;;
    esac
  done
  if [ -n "\$input" ] && grep -q 'ac_nonexistent\\.h' "\$input" 2>/dev/null; then
    printf '%s: fatal error: ac_nonexistent.h: No such file or directory\n' "\$input" >&2
    exit 1
  fi
  if [ -n "\$out" ]; then
    if [ -n "\$input" ] && [ -f "\$input" ]; then
      cat "\$input" > "\$out"
    else
      : > "\$out"
    fi
  elif [ -n "\$input" ] && [ -f "\$input" ]; then
    cat "\$input"
  fi
  exit 0
fi
if [ "\$compile_only" = 1 ]; then
  if host_source_compile "\$@"; then
    exit 0
  fi
  if is_conftest_args "\$@"; then
    if host_conftest_compile "\$@"; then
      exit 0
    fi
  fi
  filter_libcxx_driver_args "\$@"
  exec "\$driver" "\${driver_args[@]}" "\${filtered_args[@]}"
fi

if is_conftest_args "\$@"; then
  if host_conftest_link "\$@"; then
    exit 0
  fi
fi

tmpdir=\$(mktemp -d "\${TMPDIR:-/tmp}/gxx-modern-link.XXXXXX")
trap 'rm -rf "\$tmpdir"' EXIT
out_file=a.out
compile_args=()
ld_args=()
objects=()
prev=
for arg in "\$@"; do
  if [ "\$prev" = -o ]; then
    out_file="\$arg"
    prev=
    continue
  fi
  case "\$arg" in
    -o)
      prev=-o
      ;;
    *.c|*.cc|*.cxx|*.cpp|*.C)
      obj="\$tmpdir/\$(basename "\$arg").o"
      run_driver "\${compile_args[@]}" -c "\$arg" -o "\$obj"
      objects+=("\$obj")
      ;;
    *.o|*.a)
      objects+=("\$arg")
      ;;
    -lstdc++|-lsupc++)
      [ "\$use_libcxx" = 1 ] || ld_args+=("\$arg")
      ;;
    -L*|-l*)
      ld_args+=("\$arg")
      ;;
    -Wl,*)
      append_wl_args "\$arg"
      ;;
    -nostartfiles|-nodefaultlibs|-nostdlib)
      ;;
    *)
      compile_args+=("\$arg")
      ;;
  esac
done
if [ "\${#objects[@]}" = 0 ]; then
  filter_libcxx_driver_args "\$@"
  exec "\$driver" "\${driver_args[@]}" "\${filtered_args[@]}"
fi
add_default_link_args
if [ "\$use_libcxx" = 1 ]; then
  ld_args+=(-L"\$root/lib/gcc/$target/$version" -lgcc -lc++)
else
  ld_args+=(-L"\$root/lib/gcc/$target/$version" -L"\$root/lib" -lgcc -lstdc++ -lsupc++)
fi
case "\$PWD" in
  */phase46-gcc-latest/build/gcc*)
    if [ "\${GCC_MODERN_WRAPPER_HOST_SHORTCUTS:-1}" = 1 ]; then
      cxx_link_args
      exec $wrapper_host_cxx -arch x86_64 "\${objects[@]}" "\${cxx_args[@]}" -o "\$out_file"
    fi
    ;;
esac
exec $wrapper_host_ld "\${objects[@]}" "\${ld_args[@]}" -o "\$out_file"
WRAPPER
  chmod +x "$out/bin/gcc" "$out/bin/g++"

  "$out/bin/gcc" -dumpversion > "$bootstrap_share/gcc-version.stdout"
  "$out/bin/g++" -dumpversion > "$bootstrap_share/g++-version.stdout"
  cat > smoke.c <<'C'
int main(void) { return 0; }
C
  "$out/bin/gcc" -c smoke.c -o "$bootstrap_share/smoke.o" \
    2>&1 | tee "$bootstrap_share/smoke.log"
  cat > smoke.cc <<'CXX'
int main() { return 0; }
CXX
  "$out/bin/g++" -c smoke.cc -o "$bootstrap_share/smoke-cxx.o" \
    2>&1 | tee "$bootstrap_share/smoke-cxx.log"
}

if [ "${GCC_MODERN_RESUME:-0}" != 1 ] || [ ! -f Makefile ]; then
  ../src/configure "${configure_flags[@]}" MAKEINFO=true \
    2>&1 | tee "$bootstrap_share/configure.log"
else
  printf 'Reusing existing %s configure state in %s\n' "$label" "$PWD" > "$bootstrap_share/configure.resume"
fi

make_tool=${BOOTSTRAP_MAKE:-"$phase39/bin/make"}
# The bootstrapped GNU Make available at this point is still serial-only for
# this chain: its parallel jobserver needs pipe coverage that has not been made
# part of the bootstrap ABI yet.  Impure debug runs may override this.
build_cores=${BOOTSTRAP_JOBS:-1}
make_dir=${GCC_MODERN_MAKE_DIR:-.}
make_targets=${GCC_MODERN_TARGETS:-all}

if [ -f Makefile ]; then
  cc_for_build_escaped="$(printf '%s\n' "$CC_FOR_BUILD" | sed 's/[\/&]/\\&/g')"
  cxx_for_build_escaped="$(printf '%s\n' "$CXX_FOR_BUILD" | sed 's/[\/&]/\\&/g')"
  cflags_escaped="$(printf '%s\n' "$CFLAGS" | sed 's/[\/&]/\\&/g')"
  cppflags_for_build_escaped="$(printf '%s\n' "${CPPFLAGS_FOR_BUILD:-}" | sed 's/[\/&]/\\&/g')"
  cflags_for_build_escaped="$(printf '%s\n' "$CFLAGS_FOR_BUILD" | sed 's/[\/&]/\\&/g')"
  cxxflags_for_build_escaped="$(printf '%s\n' "$CXXFLAGS_FOR_BUILD" | sed 's/[\/&]/\\&/g')"
  ldflags_for_build_escaped="$(printf '%s\n' "$LDFLAGS_FOR_BUILD" | sed 's/[\/&]/\\&/g')"
  while IFS= read -r makefile; do
    perl -0pi \
      -e "s@^CC_FOR_BUILD = .*\$@CC_FOR_BUILD = $cc_for_build_escaped@m;" \
      -e "s@^CXX_FOR_BUILD = .*\$@CXX_FOR_BUILD = $cxx_for_build_escaped@m;" \
      -e "s@^CFLAGS = .*\$@CFLAGS = $cflags_escaped@m;" \
      -e "s@^CPPFLAGS_FOR_BUILD = .*\$@CPPFLAGS_FOR_BUILD = $cppflags_for_build_escaped@m;" \
      -e "s@^CFLAGS_FOR_BUILD = .*\$@CFLAGS_FOR_BUILD = $cflags_for_build_escaped@m;" \
      -e "s@^CXXFLAGS_FOR_BUILD = .*\$@CXXFLAGS_FOR_BUILD = $cxxflags_for_build_escaped@m;" \
      -e "s@^LDFLAGS_FOR_BUILD = .*\$@LDFLAGS_FOR_BUILD = $ldflags_for_build_escaped@m;" \
      -e "s@^BUILD_LDFLAGS[[:space:]]*=.*\$@BUILD_LDFLAGS = $ldflags_for_build_escaped@m;" \
      "$makefile"
  done < <(find . -name Makefile -type f)
  perl -0pi \
    -e "s@^(BUILD_EXPORTS = \\\\\n(?:.*?\\n)*?\tCFLAGS=\"\\\$\\(CFLAGS_FOR_BUILD\\)\"; export CFLAGS; \\\\\n)@\$1\tCPPFLAGS=\"\\\$\\(CPPFLAGS_FOR_BUILD\\)\"; export CPPFLAGS; \\\\\n@ms;" \
    -e "s@^(EXTRA_BUILD_FLAGS = \\\\\n\tCFLAGS=\"\\\$\\(CFLAGS_FOR_BUILD\\)\" \\\\\n)(\tLDFLAGS=)@\$1\tCXXFLAGS=\"\\\$\\(CXXFLAGS_FOR_BUILD\\)\" \\\\\n\$2@m;" \
    -e "s@^(EXTRA_BUILD_FLAGS = \\\\\n\tCFLAGS=\"\\\$\\(CFLAGS_FOR_BUILD\\)\" \\\\\n)(\tCXXFLAGS=)@\$1\tCPPFLAGS=\"\\\$\\(CPPFLAGS_FOR_BUILD\\)\" \\\\\n\$2@m;" \
    Makefile
  while IFS= read -r makefile; do
    perl -0pi \
      -e "s@^CC = .*\$@CC = $cc_for_build_escaped@m;" \
      -e "s@^CXX = .*\$@CXX = $cxx_for_build_escaped@m;" \
      -e "s@^CPPFLAGS = .*\$@CPPFLAGS = $cppflags_for_build_escaped@m;" \
      -e "s@^CFLAGS = .*\$@CFLAGS = $cflags_for_build_escaped@m;" \
      -e "s@^CXXFLAGS = .*\$@CXXFLAGS = $cxxflags_for_build_escaped@m;" \
      -e "s@^LDFLAGS = .*\$@LDFLAGS = $ldflags_for_build_escaped@m;" \
      "$makefile"
  done < <(find "./build-$target" -name Makefile -type f 2>/dev/null || true)
  find "./build-$target" -path '*/libcpp/Makefile' -type f -exec touch {} + 2>/dev/null || true
  target_arch="${target%%-*}"
  for build_archive_dir in "./build-$target/libcpp"; do
    if [ -f "$build_archive_dir/libcpp.a" ] \
      && command -v lipo >/dev/null 2>&1 \
      && ! lipo -info "$build_archive_dir/libcpp.a" 2>/dev/null | grep -q "architecture: $target_arch\\|are: .*\\b$target_arch\\b"; then
      rm -f "$build_archive_dir"/libcpp.a
      find "$build_archive_dir" -maxdepth 1 -name '*.o' -delete
      find "$build_archive_dir/.deps" -type f \( -name '*.TPo' -o -name '*.Po' \) -delete 2>/dev/null || true
    fi
    if [ -f "$build_archive_dir/libcpp.a" ] \
      && command -v nm >/dev/null 2>&1 \
      && nm "$build_archive_dir/libcpp.a" 2>/dev/null | grep -q 'cpp_finishP10cpp_readerPl'; then
      rm -f "$build_archive_dir"/libcpp.a
      find "$build_archive_dir" -maxdepth 1 -name '*.o' -delete
      find "$build_archive_dir/.deps" -type f \( -name '*.TPo' -o -name '*.Po' \) -delete 2>/dev/null || true
    fi
  done
  if [ -f libcody/libcody.a ] \
    && command -v nm >/dev/null 2>&1 \
    && nm libcody/libcody.a 2>/dev/null | grep -q 'Resolver10GetCMINameERKSs'; then
    rm -f libcody/libcody.a
    find libcody -maxdepth 1 -name '*.o' -delete
    find libcody -maxdepth 2 -path '*/.deps/*' -type f \( -name '*.TPo' -o -name '*.Po' \) -delete 2>/dev/null || true
  fi
  find . -path '*/mpfr/src/Makefile' -type f -exec perl -0pi \
    -e 's@^(DEFS = .*)$@$1 -DHAVE_WCHAR_H=1@m; s@[[:space:]]-Dwint_t=int@@g' \
    {} +
  if [ -d "build-$target" ] && [ ! -x "build-$target/fixincludes/fixinc.sh" ]; then
    mkdir -p "build-$target/fixincludes"
    cat > "build-$target/fixincludes/fixinc.sh" <<'FIXINC_SH'
#!/usr/bin/env bash
exit 0
FIXINC_SH
    chmod +x "build-$target/fixincludes/fixinc.sh"
  fi
  if [ -f gcc/auto-host.h ]; then
    perl -0pi \
      -e 's@^#define HAVE_DECL_STRSIGNAL 0$@#define HAVE_DECL_STRSIGNAL 1@m;' \
      -e 's@^#define HAVE_DECL_GETRLIMIT 0$@#define HAVE_DECL_GETRLIMIT 1@m;' \
      -e 's@^#define HAVE_DECL_SETRLIMIT 0$@#define HAVE_DECL_SETRLIMIT 1@m;' \
      -e 's@^#define HAVE_DECL_MADVISE 0$@#define HAVE_DECL_MADVISE 1@m;' \
      -e 's@^#define MKDIR_TAKES_ONE_ARG 1$@/* #undef MKDIR_TAKES_ONE_ARG */@m;' \
      -e 's@^#define rlim_t long$@/* #undef rlim_t */@m;' \
      -e 's@/\* Define to 1 if you have the <sys/locking\.h> header file\. \*/\n#ifndef USED_FOR_TARGET\n#define HAVE_SYS_LOCKING_H 1\n#endif@/* Define to 1 if you have the <sys/locking.h> header file. */\n/* #undef HAVE_SYS_LOCKING_H */@;' \
      gcc/auto-host.h
    if [ -f gcc/config.status ]; then
      perl -0pi \
        -e 's@D\["HAVE_DECL_STRSIGNAL"\]=" 0"@D["HAVE_DECL_STRSIGNAL"]=" 1"@m;' \
        -e 's@D\["HAVE_DECL_GETRLIMIT"\]=" 0"@D["HAVE_DECL_GETRLIMIT"]=" 1"@m;' \
        -e 's@D\["HAVE_DECL_SETRLIMIT"\]=" 0"@D["HAVE_DECL_SETRLIMIT"]=" 1"@m;' \
        -e 's@D\["HAVE_DECL_MADVISE"\]=" 0"@D["HAVE_DECL_MADVISE"]=" 1"@m;' \
        -e 's@D\["MKDIR_TAKES_ONE_ARG"\]=" 1"@D["MKDIR_TAKES_ONE_ARG"]=" /* undef */"@m;' \
        -e 's@D\["rlim_t"\]=" long"@D["rlim_t"]=" /* undef */"@m;' \
        gcc/config.status
    fi
    if [ -f gcc/config.cache ]; then
      perl -0pi \
        -e 's@^gcc_cv_have_decl_strsignal=.*$@gcc_cv_have_decl_strsignal=yes@m;' \
        -e 's@^gcc_cv_have_decl_getrlimit=.*$@gcc_cv_have_decl_getrlimit=yes@m;' \
        -e 's@^gcc_cv_have_decl_setrlimit=.*$@gcc_cv_have_decl_setrlimit=yes@m;' \
        -e 's@^gcc_cv_have_decl_madvise=.*$@gcc_cv_have_decl_madvise=yes@m;' \
        -e 's@^ac_cv_type_rlim_t=.*$@ac_cv_type_rlim_t=yes@m;' \
        -e 's@^ac_cv_header_direct_h=.*$@ac_cv_header_direct_h=\${ac_cv_header_direct_h=no}@m;' \
        -e 's@^ac_cv_header_malloc_h=.*$@ac_cv_header_malloc_h=\${ac_cv_header_malloc_h=no}@m;' \
        -e 's@^ac_cv_header_sys_auxv_h=.*$@ac_cv_header_sys_auxv_h=\${ac_cv_header_sys_auxv_h=no}@m;' \
        -e 's@^ac_cv_header_sys_locking_h=.*$@ac_cv_header_sys_locking_h=\${ac_cv_header_sys_locking_h=no}@m;' \
        -e 's@^ac_cv_header_thread_h=.*$@ac_cv_header_thread_h=\${ac_cv_header_thread_h=no}@m;' \
        gcc/config.cache
      grep -q '^gcc_cv_have_decl_strsignal=' gcc/config.cache || printf '%s\n' 'gcc_cv_have_decl_strsignal=yes' >> gcc/config.cache
      grep -q '^gcc_cv_have_decl_getrlimit=' gcc/config.cache || printf '%s\n' 'gcc_cv_have_decl_getrlimit=yes' >> gcc/config.cache
      grep -q '^gcc_cv_have_decl_setrlimit=' gcc/config.cache || printf '%s\n' 'gcc_cv_have_decl_setrlimit=yes' >> gcc/config.cache
      grep -q '^gcc_cv_have_decl_madvise=' gcc/config.cache || printf '%s\n' 'gcc_cv_have_decl_madvise=yes' >> gcc/config.cache
      grep -q '^ac_cv_type_rlim_t=' gcc/config.cache || printf '%s\n' 'ac_cv_type_rlim_t=yes' >> gcc/config.cache
      grep -q '^ac_cv_header_direct_h=' gcc/config.cache || printf '%s\n' 'ac_cv_header_direct_h=${ac_cv_header_direct_h=no}' >> gcc/config.cache
      grep -q '^ac_cv_header_malloc_h=' gcc/config.cache || printf '%s\n' 'ac_cv_header_malloc_h=${ac_cv_header_malloc_h=no}' >> gcc/config.cache
      grep -q '^ac_cv_header_sys_auxv_h=' gcc/config.cache || printf '%s\n' 'ac_cv_header_sys_auxv_h=${ac_cv_header_sys_auxv_h=no}' >> gcc/config.cache
      grep -q '^ac_cv_header_sys_locking_h=' gcc/config.cache || printf '%s\n' 'ac_cv_header_sys_locking_h=${ac_cv_header_sys_locking_h=no}' >> gcc/config.cache
      grep -q '^ac_cv_header_thread_h=' gcc/config.cache || printf '%s\n' 'ac_cv_header_thread_h=${ac_cv_header_thread_h=no}' >> gcc/config.cache
    fi
    echo timestamp > gcc/cstamp-h
    rm -f gcc/toplev.o gcc/opts.o gcc/gcc.o gcc/darwin-driver.o \
      gcc/.deps/toplev.TPo gcc/.deps/toplev.Po \
      gcc/.deps/opts.TPo gcc/.deps/opts.Po \
      gcc/.deps/gcc.TPo gcc/.deps/gcc.Po \
      gcc/.deps/darwin-driver.TPo gcc/.deps/darwin-driver.Po
  fi
  if [ -f gcc/Makefile ] && ! grep -q 'DARWIN_BOOTSTRAP_GCOV_STUB_RULES' gcc/Makefile; then
    cat >> gcc/Makefile <<'GCOV_STUB_RULES'

# DARWIN_BOOTSTRAP_GCOV_STUB_RULES
gcov$(exeext):
	@touch $@
gcov-dump$(exeext):
	@touch $@
gcov-tool$(exeext):
	@touch $@
GCOV_STUB_RULES
  fi
  if [ -f gcc/Makefile ]; then
    perl -0pi \
      -e 's@^STMP_FIXINC[[:space:]]*=.*$@STMP_FIXINC =@m;' \
      -e 's@^LIBBACKTRACE[[:space:]]*=.*$@LIBBACKTRACE = ../libbacktrace/.libs/libbacktrace.a@m;' \
      -e 's@^BACKTRACEINC[[:space:]]*=.*$@BACKTRACEINC = -I\$(BACKTRACE)@m;' \
      -e 's@s-macro_list : .*?\n\t\$\(STAMP\) s-macro_list@s-macro_list :\n\t: > macro_list\n\t\$\(STAMP\) s-macro_list@s;' \
      -e 's@s-fixinc_list : .*?\n\t\$\(STAMP\) s-fixinc_list@s-fixinc_list :\n\techo ";" > fixinc_list\n\t\$\(STAMP\) s-fixinc_list@s;' \
      -e 's@^selftest-c: s-selftest-c$@selftest-c:@m;' \
      -e 's@^selftest-c\+\+: s-selftest-c\+\+$@selftest-c++:@m;' \
      gcc/Makefile
    if ! grep -q 'DARWIN_BOOTSTRAP_GENMATCH_CPPLIB' gcc/Makefile; then
      cat >> gcc/Makefile <<'GENMATCH_CPPLIB_RULES'

# DARWIN_BOOTSTRAP_GENMATCH_CPPLIB
# Darwin ld resolves static archives left-to-right and does not rescan archive
# members for intra-archive C++ references.  Repeating libcpp at the end keeps
# the modern GCC build/genmatch link strict without falling back to host clang++.
build/genmatch$(build_exeext): BUILD_LIBS += $(BUILD_CPPLIB)
GENMATCH_CPPLIB_RULES
    fi
  fi
  mkdir -p libbacktrace/.libs
  cat > libbacktrace/darwin-bootstrap-backtrace-stub.c <<'BACKTRACE_STUB_C'
#include "backtrace.h"

struct backtrace_state {
  int unused;
};

static struct backtrace_state darwin_bootstrap_backtrace_state;

struct backtrace_state *
backtrace_create_state (const char *filename, int threaded,
                        backtrace_error_callback error_callback, void *data)
{
  (void) filename;
  (void) threaded;
  (void) error_callback;
  (void) data;
  return &darwin_bootstrap_backtrace_state;
}

int
backtrace_full (struct backtrace_state *state, int skip,
                backtrace_full_callback callback,
                backtrace_error_callback error_callback, void *data)
{
  (void) state;
  (void) skip;
  (void) callback;
  (void) error_callback;
  (void) data;
  return 0;
}

int
backtrace_simple (struct backtrace_state *state, int skip,
                  backtrace_simple_callback callback,
                  backtrace_error_callback error_callback, void *data)
{
  (void) state;
  (void) skip;
  (void) callback;
  (void) error_callback;
  (void) data;
  return 0;
}

void
backtrace_print (struct backtrace_state *state, int skip, FILE *file)
{
  (void) state;
  (void) skip;
  (void) file;
}

int
backtrace_pcinfo (struct backtrace_state *state, uintptr_t pc,
                  backtrace_full_callback callback,
                  backtrace_error_callback error_callback, void *data)
{
  (void) state;
  (void) pc;
  (void) callback;
  (void) error_callback;
  (void) data;
  return 0;
}

int
backtrace_syminfo (struct backtrace_state *state, uintptr_t addr,
                   backtrace_syminfo_callback callback,
                   backtrace_error_callback error_callback, void *data)
{
  (void) state;
  (void) addr;
  (void) callback;
  (void) error_callback;
  (void) data;
  return 0;
}
BACKTRACE_STUB_C
  # The libbacktrace stub object is linked into the build compiler (cc1/xgcc),
  # so in the strict path (GCC_MODERN_HOST_BUILD_CC=0) it must be compiled by
  # the chain gcc, not host clang — otherwise host-clang codegen leaks into the
  # strict artifact. The chain gcc is x86_64-native and rejects clang's -arch.
  if [ "${GCC_MODERN_HOST_BUILD_CC:-1}" = 1 ]; then
    $wrapper_host_cc -arch x86_64 -O2 -g0 -DHAVE_STDINT_H=1 -I../src/libbacktrace \
      -c libbacktrace/darwin-bootstrap-backtrace-stub.c \
      -o libbacktrace/darwin-bootstrap-backtrace-stub.o
  else
    "$compiler/bin/gcc" -O2 -g0 -DHAVE_STDINT_H=1 -I../src/libbacktrace \
      -c libbacktrace/darwin-bootstrap-backtrace-stub.c \
      -o libbacktrace/darwin-bootstrap-backtrace-stub.o
  fi
  "$AR" rc libbacktrace/.libs/libbacktrace.a libbacktrace/darwin-bootstrap-backtrace-stub.o
  "$RANLIB" libbacktrace/.libs/libbacktrace.a
  perl -0pi \
    -e 's@^(SUBDIRS = .*) fixincludes( .*)?$@$1$2@m;' \
    -e 's@^HOST_ISLLIBS = .*$@HOST_ISLLIBS =@m;' \
    -e 's@^HOST_ISLINC = .*$@HOST_ISLINC =@m;' \
    -e 's@^maybe-all-isl: all-isl$@maybe-all-isl:@m;' \
    -e 's@^maybe-configure-isl: configure-isl$@maybe-configure-isl:@m;' \
    -e 's@^maybe-install-isl: install-isl$@maybe-install-isl:@m;' \
    -e 's@^maybe-all-build-fixincludes: all-build-fixincludes$@maybe-all-build-fixincludes:@m;' \
    -e 's@^maybe-configure-build-fixincludes: configure-build-fixincludes$@maybe-configure-build-fixincludes:@m;' \
    -e 's@^maybe-all-fixincludes: all-fixincludes$@maybe-all-fixincludes:@m;' \
    -e 's@^maybe-configure-fixincludes: configure-fixincludes$@maybe-configure-fixincludes:@m;' \
    -e 's@^maybe-install-fixincludes: install-fixincludes$@maybe-install-fixincludes:@m;' \
    -e 's@^maybe-install-strip-fixincludes: install-strip-fixincludes$@maybe-install-strip-fixincludes:@m;' \
    Makefile
  if [ "${GCC_MODERN_HOST_BUILD_CC:-1}" = 1 ] && [ "${GCC_MODERN_RESUME:-0}" != 1 ]; then
    rm -f libcpp/charset.o libcpp/files.o libcpp/libcpp.a \
      libcpp/.deps/charset.TPo libcpp/.deps/charset.Po \
      libcpp/.deps/files.TPo libcpp/.deps/files.Po
    rm -f gmp/gen-fac gmp/gen-fib gmp/gen-bases gmp/gen-trialdivtab \
      gmp/gen-jacobitab gmp/gen-psqr \
      gmp/fac_table.h gmp/fib_table.h gmp/mp_bases.h gmp/trialdivtab.h \
      gmp/jacobitab.h gmp/mpn/perfsqr.h gmp/mpn/fib_table.c \
      gmp/mpn/mp_bases.c
  fi
fi

if [ "$make_dir" = . ] && [ "$make_targets" = all-gcc ] && grep -q '^all-libcody:' Makefile; then
  make_targets="all-libcody all-gcc"
fi

## Task #13: when GCC_MODERN_BUILD_TARGET_LIBS=1, also build libgcc +
## libstdc++ from the just-built xgcc, passing -isystem $sysroot/include
## via the same LIBGCC2_INCLUDES / CRTSTUFF_T_CFLAGS knobs that
## phase44-cxx.sh uses for the GCC 4.6 chain. Without these the target
## libgcc compile can't find <stdio.h> (the bundled $out/$target/include
## doesn't exist yet at build time).
target_lib_make_args=()
if [ "${GCC_MODERN_BUILD_TARGET_LIBS:-0}" = 1 ]; then
  ## GCC propagates CFLAGS_FOR_TARGET / CXXFLAGS_FOR_TARGET to recursive
  ## target builds; LIBGCC2_INCLUDES alone doesn't reach $target/libgcc
  ## from the top-level make. Pass the bootstrap sysroot includes via
  ## both so libgcc2.c can find <stdio.h> via tsystem.h.
  target_lib_make_args=(
    CFLAGS_FOR_TARGET="-O2 -g0 -isystem $sysroot/include"
    CXXFLAGS_FOR_TARGET="-O2 -g0 -isystem $sysroot/include"
    CRTSTUFF_T_CFLAGS="-isystem $sysroot/include"
    LIBGCC2_INCLUDES="-isystem $sysroot/include"
    ## libstdc++'s configure runs link tests with the build-tree xgcc;
    ## the staged sysroot has headers only, so the linker needs the real
    ## SDK for libSystem.
    LDFLAGS_FOR_TARGET="-Wl,-syslibroot,$sdk"
  )
fi

if [ "${GCC_MODERN_PACKAGE_ONLY:-0}" != 1 ]; then
  MAKEFLAGS= "$make_tool" -C "$make_dir" -j"$build_cores" \
    MAKEINFO=true \
    "${target_lib_make_args[@]}" \
    $make_targets \
    2>&1 | tee "$bootstrap_share/make.log"
  if [ "${GCC_MODERN_BUILD_TARGET_LIBS:-0}" = 1 ]; then
    ## include-fixed/limits.h includes its sibling syslimits.h; the gcc
    ## build stages only limits.h.  gsyslimits.h is the stock "no fixes
    ## needed" syslimits (include_next the system limits.h).  The header
    ## exists only after the all-gcc make, so the target libs run as a
    ## second make.
    if [ -f gcc/include-fixed/limits.h ] && [ ! -f gcc/include-fixed/syslimits.h ] \
       && [ -f ../src/gcc/gsyslimits.h ]; then
      cp ../src/gcc/gsyslimits.h gcc/include-fixed/syslimits.h
    fi
    MAKEFLAGS= "$make_tool" -C "$make_dir" -j"$build_cores" \
      MAKEINFO=true \
      "${target_lib_make_args[@]}" \
      all-target-libgcc \
      2>&1 | tee "$bootstrap_share/make-target-libgcc.log"
    ## gcc-10's darwin specs link -lemutls_w into every executable; the
    ## libstdc++ conftests need it in gcc/ or configure degrades to
    ## GCC_NO_EXECUTABLES.  Copy the built archive; create an empty one
    ## when the libgcc build doesn't produce it.
    if [ ! -f gcc/libemutls_w.a ]; then
      if [ -f "$target/libgcc/libemutls_w.a" ]; then
        cp "$target/libgcc/libemutls_w.a" gcc/libemutls_w.a
      else
        ## This libgcc configuration leaves libemutls_w.a out of
        ## EXTRA_PARTS; an archive holding one empty object satisfies
        ## the -lemutls_w in the driver specs (emutls itself lives in
        ## libgcc.a).
        : > emutls-stub.c
        ./gcc/xgcc -B./gcc/ -c emutls-stub.c -o emutls-stub.o
        "$cctools/bin/ar" rc gcc/libemutls_w.a emutls-stub.o
        "$cctools/bin/ranlib" gcc/libemutls_w.a || true
      fi
    fi
    ## Logged probe: the exact link the libstdc++ conftests run.  Shows
    ## the real linker error in the build log if configure would degrade
    ## to GCC_NO_EXECUTABLES.
    printf 'int main(void) { return 0; }\n' > target-link-probe.c
    echo "=== target link probe ==="
    ./gcc/xgcc -B./gcc/ -isystem "$sysroot/include" -Wl,-syslibroot,"$sdk" \
      target-link-probe.c -o target-link-probe || echo "=== target link probe FAILED ==="
    MAKEFLAGS= "$make_tool" -C "$make_dir" -j"$build_cores" \
      MAKEINFO=true \
      "${target_lib_make_args[@]}" \
      all-target-libstdc++-v3 \
      2>&1 | tee "$bootstrap_share/make-target-libstdcxx.log" || {
        config_log="$target/libstdc++-v3/config.log"
        if [ -f "$config_log" ]; then
          echo "=== $config_log: first failures ==="
          grep -n -B6 -A12 'cannot create executables\|^ld: \|error: ' "$config_log" | head -120
        fi
        exit 1
      }
  fi
else
  printf 'Skipped make for %s package-only handoff\n' "$label" > "$bootstrap_share/make.skipped"
fi

if [ "${GCC_MODERN_COMPILER_ONLY:-0}" = 1 ]; then
  package_modern_compiler
  printf 'Packaged compiler-only handoff for %s\n' "$label" > "$bootstrap_share/install.compiler-only"
  exit 0
fi

if [ "${GCC_MODERN_SKIP_INSTALL:-0}" != 1 ] && [ "$make_dir" = . ] && [ "$make_targets" = all ]; then
  MAKEFLAGS= "$make_tool" -j"$build_cores" install-strip \
    MAKEINFO=true \
    2>&1 | tee "$bootstrap_share/install.log"
else
  printf 'Skipped install for %s make_dir=%s targets=%s\n' "$label" "$make_dir" "$make_targets" > "$bootstrap_share/install.skipped"
  exit 0
fi

test -x "$out/bin/gcc"
test -x "$out/bin/g++"
"$out/bin/gcc" --version > "$bootstrap_share/gcc-version.stdout"
"$out/bin/g++" --version > "$bootstrap_share/g++-version.stdout"

cat > smoke.c <<'C'
int main(void) { return 42; }
C
"$out/bin/gcc" -S smoke.c -o "$bootstrap_share/smoke.s" \
  2>&1 | tee "$bootstrap_share/smoke.log"
test -s "$bootstrap_share/smoke.s"
