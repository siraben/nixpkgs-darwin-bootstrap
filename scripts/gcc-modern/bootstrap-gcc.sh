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
if [ -f src/gcc/diagnostic.c ] && grep -q 'isatty (fileno (pp_buffer (context->printer)->stream))' src/gcc/diagnostic.c; then
  perl -0pi -e 's@value = value \? value - 1\s*: \(isatty \(fileno \(pp_buffer \(context->printer\)->stream\)\)\s*\? get_terminal_width \(\) - 1: INT_MAX\);@value = value ? value - 1 : INT_MAX;@s' src/gcc/diagnostic.c
fi
if [ -f src/gcc/diagnostic.c ] && grep -q 'get_terminal_width (void)' src/gcc/diagnostic.c; then
  perl -0pi -e 's@int\nget_terminal_width \(void\)\n\{.*?\n\}@int\nget_terminal_width (void)\n{\n  return INT_MAX;\n}@s' src/gcc/diagnostic.c
fi
if [ -f src/gcc/gcc.c ] && grep -q 'not configured with sysroot headers suffix' src/gcc/gcc.c; then
  perl -0pi -e 's@if \(print_sysroot_headers_suffix\)\s*\{\s*if \(\*sysroot_hdrs_suffix_spec\)\s*\{\s*printf\("%s\\n", \(target_sysroot_hdrs_suffix\s*\? target_sysroot_hdrs_suffix\s*: ""\)\);\s*return \(0\);\s*\}\s*else\s*/\* The error status indicates that only one set of fixed\s*headers should be built\.  \*/\s*fatal_error \(input_location,\s*"not configured with sysroot headers suffix"\);\s*\}@if (print_sysroot_headers_suffix)\n    {\n      printf("%s\\n", (*sysroot_hdrs_suffix_spec && target_sysroot_hdrs_suffix\n                      ? target_sysroot_hdrs_suffix\n                      : ""));\n      return (0);\n    }@s' src/gcc/gcc.c
fi
if [ -f src/libgcc/configure ] && grep -q 'grep host_address=' src/libgcc/configure; then
  perl -0pi -e 's@cat > conftest\.c <<EOF\n#if defined\(__x86_64__\).*?eval `\$\{CC-cc\} -E conftest\.c \| grep host_address=`\nrm -f conftest\.c@host_address=64@s' src/libgcc/configure
fi
if [ -f src/libgcc/config.host ] && grep -q 'libemutls_w\.a' src/libgcc/config.host; then
  perl -0pi -e 's@ libemutls_w\.a@@g' src/libgcc/config.host
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

if [ ! -x "$compiler/bin/g++" ]; then
  echo "$label requires a bootstrapped C++ compiler at $compiler/bin/g++" >&2
  exit 1
fi

cd build
if [ -d "$compiler/$target/include" ]; then
  sysroot="$compiler/$target"
elif [ -d "$phase34/include/tcc-darwin-bootstrap" ]; then
  sysroot="$phase34/include/tcc-darwin-bootstrap"
else
  echo "$label cannot find a bootstrap sysroot in $compiler/$target or $phase34/include/tcc-darwin-bootstrap" >&2
  exit 1
fi
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
if [ -f "$sysroot/include/dirent.h" ] && ! grep -q 'extern "C"' "$sysroot/include/dirent.h"; then
  perl -0pi -e 's@(struct dirent \{[^\n]*\};\n)@$1#ifdef __cplusplus\nextern "C" {\n#endif\n@; s@(#endif\n)\z@#ifdef __cplusplus\n}\n#endif\n$1@' "$sysroot/include/dirent.h"
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
if [ -f "$sysroot/include/sys/sysctl.h" ] && ! grep -q 'extern "C"' "$sysroot/include/sys/sysctl.h"; then
  perl -0pi -e 's@(#define KERN_OSRELEASE 2\n)@$1#ifdef __cplusplus\nextern "C" {\n#endif\n@; s@(#endif\n)\z@#ifdef __cplusplus\n}\n#endif\n$1@' "$sysroot/include/sys/sysctl.h"
fi
if ! grep -q '_PC_PATH_MAX' "$sysroot/include/unistd.h"; then
  perl -0pi -e 's@(#ifdef __cplusplus\n}\n#endif\n#endif\n)\z@#ifndef _PC_PATH_MAX\n#define _PC_PATH_MAX 5\n#endif\nlong pathconf(const char *, int);\nchar *realpath(const char *, char *);\n$1@' "$sysroot/include/unistd.h"
fi
if ! grep -q 'getpagesize' "$sysroot/include/unistd.h"; then
  perl -0pi -e 's@(#ifdef __cplusplus\n}\n#endif\n#endif\n)\z@int getpagesize(void);\nint vfork(void);\n$1@' "$sysroot/include/unistd.h"
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
if [ -f "$sysroot/include/stdlib.h" ] && ! grep -q 'MB_CUR_MAX ' "$sysroot/include/stdlib.h"; then
  perl -0pi -e 's@(#define EXIT_FAILURE 1\n)@$1#ifndef MB_CUR_MAX\n#define MB_CUR_MAX 1\n#endif\n#ifndef MB_CUR_MAX_L\n#define MB_CUR_MAX_L(x) (1)\n#endif\n@' "$sysroot/include/stdlib.h"
fi
if ! grep -q 'INTMAX_MAX' "$sysroot/include/stdint.h"; then
  perl -0pi -e 's@(#endif\n)\z@#define INTMAX_MAX 9223372036854775807L\n#define INTMAX_MIN (-INTMAX_MAX - 1L)\n#define UINTMAX_MAX 18446744073709551615UL\n$1@' "$sysroot/include/stdint.h"
fi
if ! grep -q 'SIZE_MAX' "$sysroot/include/stdint.h"; then
  perl -0pi -e 's@(#define UINTMAX_MAX 18446744073709551615UL\n)@$1#define SIZE_MAX 18446744073709551615UL\n@' "$sysroot/include/stdint.h"
fi
if ! grep -q 'PTRDIFF_MAX' "$sysroot/include/stdint.h"; then
  perl -0pi -e 's@(#define SIZE_MAX 18446744073709551615UL\n)@$1#define PTRDIFF_MAX 9223372036854775807L\n#define PTRDIFF_MIN (-PTRDIFF_MAX - 1L)\n@' "$sysroot/include/stdint.h"
fi
if [ -f "$sysroot/include/inttypes.h" ] && ! grep -q 'PRIi64' "$sysroot/include/inttypes.h"; then
  perl -0pi -e 's@(#endif\n)\z@#define PRId64 "ld"\n#define PRIi64 "li"\n#define PRIu64 "lu"\n#define PRIx64 "lx"\n#define PRIX64 "lX"\n$1@' "$sysroot/include/inttypes.h"
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
#ifndef MB_CUR_MAX_L
#define MB_CUR_MAX_L(x) (1)
#endif
locale_t uselocale(locale_t);
#endif
XLOCALE_H
fi
if [ -f "$sysroot/include/sys/resource.h" ] && ! grep -q 'getrusage' "$sysroot/include/sys/resource.h"; then
  perl -0pi -e 's@(#endif\n)\z@#ifdef __cplusplus\nextern "C" {\n#endif\nint getrusage(int, struct rusage *);\n#ifdef __cplusplus\n}\n#endif\n$1@' "$sysroot/include/sys/resource.h"
fi
if [ -f "$sysroot/include/sys/resource.h" ] && ! grep -q 'RLIMIT_CORE' "$sysroot/include/sys/resource.h"; then
  perl -0pi -e 's@(#define RUSAGE_CHILDREN -1\n)@$1#define RLIMIT_CORE 4\n#define RLIM_INFINITY 9223372036854775807UL\n@' "$sysroot/include/sys/resource.h"
fi

sdk_path() {
  if [ -n "${GCC_MODERN_SDK_PATH:-}" ]; then
    printf '%s\n' "$GCC_MODERN_SDK_PATH"
  elif command -v xcrun >/dev/null 2>&1; then
    xcrun --sdk macosx --show-sdk-path
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
if [ "${GCC_MODERN_HOST_BUILD_CC:-1}" != 1 ]; then
  build_cc="$cc $bootstrap_link_flags"
  build_cxx="$cxx $bootstrap_link_flags"
fi
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
export PATH="$compiler/bin:$cctools/bin:$PATH"
  export MACOSX_DEPLOYMENT_TARGET=10.8
  export CFLAGS="${GCC_MODERN_CFLAGS:--O2 -g0 -Dwint_t=int}"
  export CXXFLAGS="${GCC_MODERN_CXXFLAGS:--O2 -g0 -std=c++14}"
  export CFLAGS_FOR_BUILD="${GCC_MODERN_CFLAGS_FOR_BUILD:--O2 -g0 -Wno-error=format-security -Wno-unknown-warning-option -Wno-error=implicit-function-declaration}"
  export CXXFLAGS_FOR_BUILD="${GCC_MODERN_CXXFLAGS_FOR_BUILD:--O2 -g0 -std=c++14 -Wno-error=format-security -Wno-unknown-warning-option -Wno-error=implicit-function-declaration}"
export CFLAGS_FOR_TARGET="${GCC_MODERN_CFLAGS_FOR_TARGET:--O2 -g0}"
export CXXFLAGS_FOR_TARGET="${GCC_MODERN_CXXFLAGS_FOR_TARGET:--O2 -g0}"
export LDFLAGS="${GCC_MODERN_LDFLAGS:-$bootstrap_link_flags}"
export LDFLAGS_FOR_BUILD="${GCC_MODERN_LDFLAGS_FOR_BUILD:-}"
export GMP_CONFIGURE_ARGS="--disable-assembly"
export CPPFLAGS_FOR_TARGET="-isystem $sysroot/include"
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
  --without-isl
  --with-glibc-version=0.0
  --disable-nls
  --disable-shared
  --disable-threads
  --enable-languages=c,c++
)

if [ "$label" = gcc-latest ]; then
  export ac_cv_prog_cc_c99=no
  export ac_cv_prog_cc_c89=no
  export ac_cv_prog_cc_stdc=no
  export ac_cv_prog_CPP="$CC -E"
  export ac_cv_header_stdc=yes
  export ac_cv_header_minix_config_h=no
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
  for archive in libstdc++.a libsupc++.a; do
    if [ -f "$compiler/lib/$archive" ]; then
      cp "$compiler/lib/$archive" "$out/lib/"
    fi
  done
  if [ -d "$compiler/include/c++" ]; then
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
  for arg in "\${ld_args[@]}"; do
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
  /usr/bin/cc -arch x86_64 -c "\${host_args[@]}" "\$source" -o "\$out"
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
    */phase46-gcc-latest/build/gcc*:*|*/phase46-gcc-latest/build/libiberty*:*|*/phase46-gcc-latest/build/libcpp*:*|*/phase46-gcc-latest/build/libdecnumber*:*|*/phase46-gcc-latest/build/zlib*:*|*/phase46-gcc-latest/build/gmp*:*|*/phase46-gcc-latest/build/mpfr*:*|*/phase46-gcc-latest/build/mpc*:*|*/phase46-gcc-latest/build/libbacktrace*:*|*/phase46-gcc-latest/build/libcody*:*|*/phase46-gcc-latest/build/fixincludes*:*|*/phase46-gcc-latest/build/build-*/fixincludes*:*)
      /usr/bin/cc -arch x86_64 -Wno-error=format-security -Wno-error=implicit-function-declaration -Wno-error=unguarded-availability "\${host_args[@]}"
      exit "\$?"
      ;;
    */src/gcc/*|*/src/libiberty/*|*/src/libcpp/*|*/src/libdecnumber/*|*/src/zlib/*|*/src/gmp/*|*/src/mpfr/*|*/src/mpc/*|*/src/libbacktrace/*|*/src/libcody/*|*/src/fixincludes/*)
      /usr/bin/cc -arch x86_64 -Wno-error=format-security -Wno-error=implicit-function-declaration -Wno-error=unguarded-availability "\${host_args[@]}"
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
  /usr/bin/cc -arch x86_64 "\${host_args[@]}" -o "\$out"
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
    /usr/bin/cc -arch x86_64 -E "\$@"
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
case "\$PWD" in
  */phase46-gcc-latest/build/gcc*)
    cxx_link_args
    exec /usr/bin/c++ -arch x86_64 "\${objects[@]}" "\${cxx_args[@]}" -o "\$out_file"
    ;;
esac
exec /usr/bin/ld "\${objects[@]}" "\${ld_args[@]}" -o "\$out_file"
WRAPPER

  cat > "$out/bin/g++" <<WRAPPER
#!/usr/bin/env bash
set -euo pipefail
root=\$(cd "\$(dirname "\$0")/.." && pwd)
default_sdk="$sdk"
cxx_inc=\$(ls -d "\$root"/include/c++/* 2>/dev/null | sort | tail -1 || true)
driver="\$root/libexec/gcc/$target/$version/xg++"
driver_args=(-B"\$root/libexec/gcc/$target/$version/" -B"\$root/lib/gcc/$target/$version/" --sysroot="\$root/$target" -isystem "\$root/$target/include" -isystem "\$default_sdk/usr/include")
if [ -n "\$cxx_inc" ] && [ -d "\$cxx_inc" ]; then
  driver_args+=(-nostdinc++ -isystem "\$cxx_inc" -isystem "\$cxx_inc/$target")
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
  for arg in "\${ld_args[@]}"; do
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
  /usr/bin/cc -arch x86_64 -c "\${host_args[@]}" "\$source" -o "\$out"
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
    */phase46-gcc-latest/build/gcc*:*|*/phase46-gcc-latest/build/libiberty*:*|*/phase46-gcc-latest/build/libcpp*:*|*/phase46-gcc-latest/build/libdecnumber*:*|*/phase46-gcc-latest/build/zlib*:*|*/phase46-gcc-latest/build/gmp*:*|*/phase46-gcc-latest/build/mpfr*:*|*/phase46-gcc-latest/build/mpc*:*|*/phase46-gcc-latest/build/libbacktrace*:*|*/phase46-gcc-latest/build/libcody*:*|*/phase46-gcc-latest/build/fixincludes*:*|*/phase46-gcc-latest/build/build-*/fixincludes*:*)
      /usr/bin/c++ -arch x86_64 -Wno-error=format-security -Wno-error=implicit-function-declaration -Wno-error=unguarded-availability "\${host_args[@]}"
      exit "\$?"
      ;;
    */src/gcc/*|*/src/libiberty/*|*/src/libcpp/*|*/src/libdecnumber/*|*/src/zlib/*|*/src/gmp/*|*/src/mpfr/*|*/src/mpc/*|*/src/libbacktrace/*|*/src/libcody/*|*/src/fixincludes/*)
      /usr/bin/c++ -arch x86_64 -Wno-error=format-security -Wno-error=implicit-function-declaration -Wno-error=unguarded-availability "\${host_args[@]}"
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
  /usr/bin/cc -arch x86_64 "\${host_args[@]}" -o "\$out"
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
    /usr/bin/c++ -arch x86_64 -E "\$@"
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
case "\$PWD" in
  */phase46-gcc-latest/build/gcc*)
    cxx_link_args
    exec /usr/bin/c++ -arch x86_64 "\${objects[@]}" "\${cxx_args[@]}" -o "\$out_file"
    ;;
esac
exec /usr/bin/ld "\${objects[@]}" "\${ld_args[@]}" -o "\$out_file"
WRAPPER
  chmod +x "$out/bin/gcc" "$out/bin/g++"

  "$out/bin/gcc" -dumpversion > "$bootstrap_share/gcc-version.stdout"
  "$out/bin/g++" -dumpversion > "$bootstrap_share/g++-version.stdout"
  cat > smoke.c <<'C'
int main(void) { return 0; }
C
  "$out/bin/gcc" -c smoke.c -o "$bootstrap_share/smoke.o" \
    > "$bootstrap_share/smoke.stdout" \
    2> "$bootstrap_share/smoke.stderr"
  cat > smoke.cc <<'CXX'
int main() { return 0; }
CXX
  "$out/bin/g++" -c smoke.cc -o "$bootstrap_share/smoke-cxx.o" \
    > "$bootstrap_share/smoke-cxx.stdout" \
    2> "$bootstrap_share/smoke-cxx.stderr"
}

if [ "${GCC_MODERN_RESUME:-0}" != 1 ] || [ ! -f Makefile ]; then
  ../src/configure "${configure_flags[@]}" MAKEINFO=true \
    > "$bootstrap_share/configure.stdout" \
    2> "$bootstrap_share/configure.stderr"
else
  printf 'Reusing existing %s configure state in %s\n' "$label" "$PWD" > "$bootstrap_share/configure.resume"
fi

if [ -f Makefile ]; then
  cc_for_build_escaped="$(printf '%s\n' "$CC_FOR_BUILD" | sed 's/[\/&]/\\&/g')"
  cxx_for_build_escaped="$(printf '%s\n' "$CXX_FOR_BUILD" | sed 's/[\/&]/\\&/g')"
  cflags_escaped="$(printf '%s\n' "$CFLAGS" | sed 's/[\/&]/\\&/g')"
  cflags_for_build_escaped="$(printf '%s\n' "$CFLAGS_FOR_BUILD" | sed 's/[\/&]/\\&/g')"
  cxxflags_for_build_escaped="$(printf '%s\n' "$CXXFLAGS_FOR_BUILD" | sed 's/[\/&]/\\&/g')"
  ldflags_for_build_escaped="$(printf '%s\n' "$LDFLAGS_FOR_BUILD" | sed 's/[\/&]/\\&/g')"
  while IFS= read -r makefile; do
    perl -0pi \
      -e "s@^CC_FOR_BUILD = .*\$@CC_FOR_BUILD = $cc_for_build_escaped@m;" \
      -e "s@^CXX_FOR_BUILD = .*\$@CXX_FOR_BUILD = $cxx_for_build_escaped@m;" \
      -e "s@^CFLAGS = .*\$@CFLAGS = $cflags_escaped@m;" \
      -e "s@^CFLAGS_FOR_BUILD = .*\$@CFLAGS_FOR_BUILD = $cflags_for_build_escaped@m;" \
      -e "s@^CXXFLAGS_FOR_BUILD = .*\$@CXXFLAGS_FOR_BUILD = $cxxflags_for_build_escaped@m;" \
      -e "s@^LDFLAGS_FOR_BUILD = .*\$@LDFLAGS_FOR_BUILD = $ldflags_for_build_escaped@m;" \
      -e "s@^BUILD_LDFLAGS[[:space:]]*=.*\$@BUILD_LDFLAGS = $ldflags_for_build_escaped@m;" \
      "$makefile"
  done < <(find . -name Makefile -type f)
  perl -0pi \
    -e "s@^(EXTRA_BUILD_FLAGS = \\\\\n\tCFLAGS=\"\\\$\\(CFLAGS_FOR_BUILD\\)\" \\\\\n)(\tLDFLAGS=)@\$1\tCXXFLAGS=\"\\\$\\(CXXFLAGS_FOR_BUILD\\)\" \\\\\n\$2@m;" \
    Makefile
  while IFS= read -r makefile; do
    perl -0pi \
      -e "s@^CC = .*\$@CC = $cc_for_build_escaped@m;" \
      -e "s@^CXX = .*\$@CXX = $cxx_for_build_escaped@m;" \
      -e "s@^CFLAGS = .*\$@CFLAGS = $cflags_for_build_escaped@m;" \
      -e "s@^CXXFLAGS = .*\$@CXXFLAGS = $cxxflags_for_build_escaped@m;" \
      -e "s@^LDFLAGS = .*\$@LDFLAGS = $ldflags_for_build_escaped@m;" \
      "$makefile"
  done < <(find "./build-$target" -name Makefile -type f 2>/dev/null || true)
  find "./build-$target" -path '*/libcpp/Makefile' -type f -exec touch {} + 2>/dev/null || true
  find . -path '*/mpfr/src/Makefile' -type f -exec perl -0pi \
    -e 's@^(DEFS = .*)$@$1 -DHAVE_WCHAR_H=1 -Dwint_t=int@m;' \
    {} +
  if [ -f gcc/auto-host.h ]; then
    perl -0pi \
      -e 's@^#define HAVE_DECL_STRSIGNAL 0$@#define HAVE_DECL_STRSIGNAL 1@m;' \
      -e 's@^#define rlim_t long$@/* #undef rlim_t */@m;' \
      gcc/auto-host.h
    if [ -f gcc/config.status ]; then
      perl -0pi \
        -e 's@D\["HAVE_DECL_STRSIGNAL"\]=" 0"@D["HAVE_DECL_STRSIGNAL"]=" 1"@m;' \
        -e 's@D\["rlim_t"\]=" long"@D["rlim_t"]=" /* undef */"@m;' \
        gcc/config.status
    fi
    if [ -f gcc/config.cache ]; then
      perl -0pi \
        -e 's@^gcc_cv_have_decl_strsignal=.*$@gcc_cv_have_decl_strsignal=yes@m;' \
        -e 's@^ac_cv_type_rlim_t=.*$@ac_cv_type_rlim_t=yes@m;' \
        gcc/config.cache
      grep -q '^gcc_cv_have_decl_strsignal=' gcc/config.cache || printf '%s\n' 'gcc_cv_have_decl_strsignal=yes' >> gcc/config.cache
      grep -q '^ac_cv_type_rlim_t=' gcc/config.cache || printf '%s\n' 'ac_cv_type_rlim_t=yes' >> gcc/config.cache
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
  /usr/bin/cc -arch x86_64 -O2 -g0 -DHAVE_STDINT_H=1 -I../src/libbacktrace \
    -c libbacktrace/darwin-bootstrap-backtrace-stub.c \
    -o libbacktrace/darwin-bootstrap-backtrace-stub.o
  "$AR" rc libbacktrace/.libs/libbacktrace.a libbacktrace/darwin-bootstrap-backtrace-stub.o
  "$RANLIB" libbacktrace/.libs/libbacktrace.a
  perl -0pi \
    -e 's@^(SUBDIRS = .*) fixincludes( .*)?$@$1$2@m;' \
    -e 's@^HOST_ISLLIBS = .*$@HOST_ISLLIBS =@m;' \
    -e 's@^HOST_ISLINC = .*$@HOST_ISLINC =@m;' \
    -e 's@^maybe-all-isl: all-isl$@maybe-all-isl:@m;' \
    -e 's@^maybe-configure-isl: configure-isl$@maybe-configure-isl:@m;' \
    -e 's@^maybe-install-isl: install-isl$@maybe-install-isl:@m;' \
    -e 's@^maybe-all-libcody: all-libcody$@maybe-all-libcody:@m;' \
    -e 's@^maybe-configure-libcody: configure-libcody$@maybe-configure-libcody:@m;' \
    -e 's@^maybe-install-libcody: install-libcody$@maybe-install-libcody:@m;' \
    -e 's@^maybe-install-strip-libcody: install-strip-libcody$@maybe-install-strip-libcody:@m;' \
    -e 's@^all-gcc: all-libcody$@all-gcc:@m;' \
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

make_tool=${BOOTSTRAP_MAKE:-"$phase39/bin/make"}
# The bootstrapped GNU Make available at this point is still serial-only for
# this chain: its parallel jobserver needs pipe coverage that has not been made
# part of the bootstrap ABI yet.  Impure debug runs may override this.
build_cores=${BOOTSTRAP_JOBS:-1}

make_dir=${GCC_MODERN_MAKE_DIR:-.}
make_targets=${GCC_MODERN_TARGETS:-all}

if [ "${GCC_MODERN_PACKAGE_ONLY:-0}" != 1 ]; then
  MAKEFLAGS= "$make_tool" -C "$make_dir" -j"$build_cores" \
    MAKEINFO=true \
    $make_targets \
    > "$bootstrap_share/make.stdout" \
    2> "$bootstrap_share/make.stderr"
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
    > "$bootstrap_share/install.stdout" \
    2> "$bootstrap_share/install.stderr"
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
  > "$bootstrap_share/smoke.stdout" \
  2> "$bootstrap_share/smoke.stderr"
test -s "$bootstrap_share/smoke.s"
