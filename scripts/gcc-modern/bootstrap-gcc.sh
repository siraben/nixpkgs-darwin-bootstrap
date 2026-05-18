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
if [ -f src/gcc/gcc.c ] && grep -q 'not configured with sysroot headers suffix' src/gcc/gcc.c; then
  perl -0pi -e 's@if \(print_sysroot_headers_suffix\)\s*\{\s*if \(\*sysroot_hdrs_suffix_spec\)\s*\{\s*printf\("%s\\n", \(target_sysroot_hdrs_suffix\s*\? target_sysroot_hdrs_suffix\s*: ""\)\);\s*return \(0\);\s*\}\s*else\s*/\* The error status indicates that only one set of fixed\s*headers should be built\.  \*/\s*fatal_error \(input_location,\s*"not configured with sysroot headers suffix"\);\s*\}@if (print_sysroot_headers_suffix)\n    {\n      printf("%s\\n", (*sysroot_hdrs_suffix_spec && target_sysroot_hdrs_suffix\n                      ? target_sysroot_hdrs_suffix\n                      : ""));\n      return (0);\n    }@s' src/gcc/gcc.c
fi
if [ -f src/libgcc/configure ] && grep -q 'grep host_address=' src/libgcc/configure; then
  perl -0pi -e 's@cat > conftest\.c <<EOF\n#if defined\(__x86_64__\).*?eval `\$\{CC-cc\} -E conftest\.c \| grep host_address=`\nrm -f conftest\.c@host_address=64@s' src/libgcc/configure
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
if ! grep -q 'INTMAX_MAX' "$sysroot/include/stdint.h"; then
  perl -0pi -e 's@(#endif\n)\z@#define INTMAX_MAX 9223372036854775807L\n#define INTMAX_MIN (-INTMAX_MAX - 1L)\n#define UINTMAX_MAX 18446744073709551615UL\n$1@' "$sysroot/include/stdint.h"
fi
if [ -f "$sysroot/include/inttypes.h" ] && ! grep -q 'PRIi64' "$sysroot/include/inttypes.h"; then
  perl -0pi -e 's@(#endif\n)\z@#define PRId64 "ld"\n#define PRIi64 "li"\n#define PRIu64 "lu"\n#define PRIx64 "lx"\n#define PRIX64 "lX"\n$1@' "$sysroot/include/inttypes.h"
fi
if [ ! -f "$sysroot/include/wchar.h" ]; then
  cat > "$sysroot/include/wchar.h" <<'WCHAR_H'
#ifndef _DARWIN_BOOTSTRAP_WCHAR_H
#define _DARWIN_BOOTSTRAP_WCHAR_H
typedef int wchar_t;
typedef int wint_t;
#endif
WCHAR_H
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
export CXXFLAGS="${GCC_MODERN_CXXFLAGS:--O2 -g0}"
export CFLAGS_FOR_BUILD="${GCC_MODERN_CFLAGS_FOR_BUILD:--O2 -g0 -Wno-error=format-security -Wno-unknown-warning-option}"
export CXXFLAGS_FOR_BUILD="${GCC_MODERN_CXXFLAGS_FOR_BUILD:--O2 -g0 -Wno-error=format-security -Wno-unknown-warning-option}"
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
  find "./build-$target" -path '*/libcpp/Makefile' -type f -exec touch {} +
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
      -e 's@s-macro_list : .*?\n\t\$\(STAMP\) s-macro_list@s-macro_list :\n\t: > macro_list\n\t\$\(STAMP\) s-macro_list@s;' \
      -e 's@s-fixinc_list : .*?\n\t\$\(STAMP\) s-fixinc_list@s-fixinc_list :\n\techo ";" > fixinc_list\n\t\$\(STAMP\) s-fixinc_list@s;' \
      -e 's@^selftest-c: s-selftest-c$@selftest-c:@m;' \
      -e 's@^selftest-c\+\+: s-selftest-c\+\+$@selftest-c++:@m;' \
      gcc/Makefile
  fi
  perl -0pi \
    -e 's@^HOST_ISLLIBS = .*$@HOST_ISLLIBS =@m;' \
    -e 's@^HOST_ISLINC = .*$@HOST_ISLINC =@m;' \
    -e 's@^maybe-all-isl: all-isl$@maybe-all-isl:@m;' \
    -e 's@^maybe-configure-isl: configure-isl$@maybe-configure-isl:@m;' \
    -e 's@^maybe-install-isl: install-isl$@maybe-install-isl:@m;' \
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

MAKEFLAGS= "$make_tool" -C "$make_dir" -j"$build_cores" \
  MAKEINFO=true \
  $make_targets \
  > "$bootstrap_share/make.stdout" \
  2> "$bootstrap_share/make.stderr"

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
