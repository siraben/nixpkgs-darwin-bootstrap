#!/usr/bin/env bash
set -euo pipefail

phase35=$1
phase37=$2
phase39=$3
phase34=$4
cctools=$5
out=$6
gcc_version=$7

target=x86_64-apple-darwin
bootstrap_share="$out/share/darwin-bootstrap"

mkdir -p src build "$out/bin" "$bootstrap_share"
if [ ! -f src/configure ]; then
  cp -R "$phase35/share/darwin-bootstrap/work/src/." src/
fi
chmod -R u+w src
if grep -q '^#if (GCC_VERSION >= 4005).*defined(__x86_64__)' src/libcpp/lex.c; then
  sed 's/^#if (GCC_VERSION >= 4005)/#if 0 \&\& (GCC_VERSION >= 4005)/' \
    src/libcpp/lex.c > src/libcpp/lex.c.bootstrap
  mv src/libcpp/lex.c.bootstrap src/libcpp/lex.c
fi
if ! grep -q DARWIN_BOOTSTRAP_NULL src/gmp/gmp-impl.h; then
  cat >> src/gmp/gmp-impl.h <<'GMP_NULL'

#ifndef DARWIN_BOOTSTRAP_NULL
#define DARWIN_BOOTSTRAP_NULL 1
#ifndef NULL
#define NULL ((void *)0)
#endif
#endif
GMP_NULL
fi
for gcc_subdir in \
  src/gcc/c-family \
  src/gcc/cp \
  src/gcc/ada/gcc-interface \
  src/gcc/java \
  src/gcc/objc \
  src/gcc/go \
  src/gcc/fortran \
  src/gcc/lto; do
  [ -d "$gcc_subdir" ] || continue
  for overlay_link in "$gcc_subdir"/*; do
    [ -L "$overlay_link" ] || continue
    overlay_target="$(readlink "$overlay_link")"
    case "$overlay_target" in
      "$PWD/src/gcc/"*|"$PWD/src/include/"*|"$PWD/src/libcpp/include/"*|"$PWD/build/gcc/"*)
        rm -f "$overlay_link"
        ;;
    esac
  done
done

# The phase37 wrapper may install temporary bootstrap C/POSIX header overlays
# into src/gcc while repairing GCC 4.6's include search.  Those headers are
# good enough for building the C driver, but they are not C++-safe: libsupc++
# needs the current phase34 sysroot headers with extern "C" declarations.
for stale_c_header in \
  assert.h \
  ctype.h \
  dirent.h \
  errno.h \
  fcntl.h \
  fnmatch.h \
  grp.h \
  inttypes.h \
  locale.h \
  math.h \
  pwd.h \
  setjmp.h \
  signal.h \
  stdbool.h \
  stdint.h \
  stdio.h \
  stdlib.h \
  string.h \
  strings.h \
  time.h \
  unistd.h \
  utime.h; do
  [ -L "src/gcc/$stale_c_header" ] && rm -f "src/gcc/$stale_c_header"
done
rm -f src/gcc/.darwin-bootstrap-root-header-overlays
if ! grep -q DARWIN_BOOTSTRAP_ASSUME_MPFR src/mpc/configure; then
  awk '
    !skip && /checking for MPFR/ {
      print "{ $as_echo \"$as_me:${as_lineno-$LINENO}: checking for MPFR\" >&5"
      print "$as_echo_n \"checking for MPFR... \" >&6; }"
      print "LIBS=\"-lmpfr $LIBS\""
      print "{ $as_echo \"$as_me:${as_lineno-$LINENO}: result: yes (DARWIN_BOOTSTRAP_ASSUME_MPFR)\" >&5"
      print "$as_echo \"yes (DARWIN_BOOTSTRAP_ASSUME_MPFR)\" >&6; }"
      skip = 1
      next
    }
    skip && /Check for a recent GMP/ {
      skip = 0
      print
      next
    }
    !skip { print }
  ' src/mpc/configure > src/mpc/configure.bootstrap
  mv src/mpc/configure.bootstrap src/mpc/configure
  chmod +x src/mpc/configure
fi

export CC="$phase37/bin/gcc"
export CPP="$CC -E"
export CC_FOR_BUILD="$CC"
export AR="$cctools/bin/ar"
export NM="$cctools/bin/nm"
export RANLIB="$cctools/bin/ranlib"
export STRIP="$cctools/bin/strip"
export LIPO="$cctools/bin/lipo"
export OTOOL="$cctools/bin/otool"
export PATH="$cctools/bin:$PATH"
export MACOSX_DEPLOYMENT_TARGET=10.8
phase44_cflags="${PHASE44_CFLAGS:--g0}"
phase44_cflags_for_build="${PHASE44_CFLAGS_FOR_BUILD:-$phase44_cflags}"
phase44_cflags_for_target="${PHASE44_CFLAGS_FOR_TARGET:--O2 -g0}"
export CFLAGS="$phase44_cflags"
export CFLAGS_FOR_BUILD="$phase44_cflags_for_build"
export CFLAGS_FOR_TARGET="$phase44_cflags_for_target"
export CXXFLAGS_FOR_TARGET="$phase44_cflags_for_target"
if [ "${GCC46_BOOTSTRAP_OBJECT_FORMAT:-elf}" = macho ]; then
  export GCC46_BOOTSTRAP_AS="${GCC46_BOOTSTRAP_AS:-/usr/bin/as}"
  export GCC46_BOOTSTRAP_LD="${GCC46_BOOTSTRAP_LD:-/usr/bin/ld}"
  export GCC46_BOOTSTRAP_MACHO_CC="${GCC46_BOOTSTRAP_MACHO_CC:-/usr/bin/cc}"
  export GCC46_BOOTSTRAP_HOST_CC="${GCC46_BOOTSTRAP_HOST_CC:-/usr/bin/cc}"
fi
export TCC_DARWIN_CACHE_DIR="$PWD/.tcc-darwin-cache"
mkdir -p "$TCC_DARWIN_CACHE_DIR"
unset CXX CXXCPP CXX_FOR_BUILD
no_host_cxx="$PWD/.no-host-cxx"
mkdir -p "$no_host_cxx"
for cxx_name in c++ g++ clang++ "$target-c++" "$target-g++"; do
  cat > "$no_host_cxx/$cxx_name" <<'NO_CXX'
#!/usr/bin/env sh
exit 1
NO_CXX
  chmod +x "$no_host_cxx/$cxx_name"
done
cat > "$no_host_cxx/cxx-cpp" <<NO_CXXCPP
#!$(command -v bash)
set -euo pipefail
tmpdir=\$(mktemp -d "\${TMPDIR:-/tmp}/gcc46-cxx-cpp.XXXXXX")
trap 'rm -rf "\$tmpdir"' EXIT HUP INT TERM
args=()
for arg in "\$@"; do
  case "\$arg" in
    *.cc|*.cpp|*.cxx|*.C)
      cp "\$arg" "\$tmpdir/input.c"
      args+=("\$tmpdir/input.c")
      ;;
    *)
      args+=("\$arg")
      ;;
  esac
done
exec "$CC" -E "\${args[@]}"
NO_CXXCPP
chmod +x "$no_host_cxx/cxx-cpp"
export CXXCPP="$no_host_cxx/cxx-cpp"
export PATH="$no_host_cxx:$PATH"

if ! grep -q DARWIN_BOOTSTRAP_GCC_GENERATOR_STAMPS src/gcc/Makefile.in; then
  cat >> src/gcc/Makefile.in <<'MAKE'

# DARWIN_BOOTSTRAP_GCC_GENERATOR_STAMPS
s-mddeps:
	@test -f mddeps.mk || touch mddeps.mk
	$(STAMP) s-mddeps
s-conditions:
	@test -f build/gencondmd.c || { mkdir -p build; touch build/gencondmd.c; }
	$(STAMP) s-conditions
s-condmd:
	@test -f insn-conditions.md
	$(STAMP) s-condmd
s-genrtl-h:
	@test -f genrtl.h
	$(STAMP) s-genrtl-h
s-modes:
	@test -f insn-modes.c
	$(STAMP) s-modes
s-modes-h:
	@test -f insn-modes.h
	$(STAMP) s-modes-h
s-modes-m:
	@test -f min-insn-modes.c
	$(STAMP) s-modes-m
s-preds:
	@test -f insn-preds.c
	$(STAMP) s-preds
s-preds-h:
	@test -f tm-preds.h
	$(STAMP) s-preds-h
s-constrs-h:
	@test -f tm-constrs.h
	$(STAMP) s-constrs-h
s-target-hooks-def-h:
	@test -f target-hooks-def.h
	$(STAMP) s-target-hooks-def-h
s-check:
	@test -f tree-check.h
	$(STAMP) s-check
s-constants:
	@test -f insn-constants.h
	$(STAMP) s-constants
s-enums:
	@test -f insn-enums.c
	$(STAMP) s-enums
s-flags:
	@test -f insn-flags.h
	$(STAMP) s-flags
s-codes:
	@test -f insn-codes.h
	$(STAMP) s-codes
s-emit:
	@test -f insn-emit.c
	$(STAMP) s-emit
s-recog:
	@test -f insn-recog.c
	$(STAMP) s-recog
s-opinit:
	@test -f insn-opinit.c
	$(STAMP) s-opinit
s-output:
	@test -f insn-output.c
	$(STAMP) s-output
s-extract:
	@test -f insn-extract.c
	$(STAMP) s-extract
s-peep:
	@test -f insn-peep.c
	$(STAMP) s-peep

# DARWIN_BOOTSTRAP_GCC_FIXINC_STAMP
stmp-fixinc:
	@mkdir -p include-fixed
	@if [ ! -f gsyslimits.h ] && [ -f $(srcdir)/gsyslimits.h ]; then cp $(srcdir)/gsyslimits.h gsyslimits.h; fi
	@if [ -f gsyslimits.h ]; then cp gsyslimits.h include-fixed/syslimits.h; else : > include-fixed/syslimits.h; fi
	$(STAMP) stmp-fixinc
MAKE
fi

if ! grep -q DARWIN_BOOTSTRAP_GCC_FIXINC_STAMP src/gcc/Makefile.in; then
  cat >> src/gcc/Makefile.in <<'MAKE'

# DARWIN_BOOTSTRAP_GCC_FIXINC_STAMP
stmp-fixinc:
	@mkdir -p include-fixed
	@if [ ! -f gsyslimits.h ] && [ -f $(srcdir)/gsyslimits.h ]; then cp $(srcdir)/gsyslimits.h gsyslimits.h; fi
	@if [ -f gsyslimits.h ]; then cp gsyslimits.h include-fixed/syslimits.h; else : > include-fixed/syslimits.h; fi
	$(STAMP) stmp-fixinc
MAKE
fi

if ! grep -q DARWIN_BOOTSTRAP_GCC_GTYPE_STAMP src/gcc/Makefile.in; then
  cat >> src/gcc/Makefile.in <<'MAKE'

# DARWIN_BOOTSTRAP_GCC_GTYPE_STAMP
s-gtype:
	@test -f gtype-desc.c
	@test -f gtype-desc.h
	@test -f gtype.state
	$(STAMP) s-gtype
s-iov:
	@test -f gcov-iov.h
	$(STAMP) s-iov
MAKE
fi

if ! grep -q DARWIN_BOOTSTRAP_GCC_GENERATOR_BINARIES src/gcc/Makefile.in; then
  cat >> src/gcc/Makefile.in <<'MAKE'

# DARWIN_BOOTSTRAP_GCC_GENERATOR_BINARIES
$(genprog:%=build/gen%$(build_exeext)):
	@test -f $@
build/gcov-iov$(build_exeext):
	@test -x $@
gcov$(exeext) gcov-dump$(exeext):
	@test -x $@
build/%.o:
	@test -f $@
MAKE
fi

cd build
target_include="$PWD/bootstrap-target-include"
mkdir -p "$target_include"
cp -R "$phase34/include/tcc-darwin-bootstrap/." "$target_include/"
chmod -R u+w "$target_include"
if [ -f "$target_include/sys/types.h" ]; then
  perl -0pi -e 's/^typedef struct \{ int quot; int rem; \} div_t;\n//m; s/^typedef struct \{ long quot; long rem; \} ldiv_t;\n//m' "$target_include/sys/types.h"
fi
if [ -f "$target_include/time.h" ] && ! grep -q '^typedef unsigned long size_t;$' "$target_include/time.h"; then
  perl -0pi -e 's/^(#define _DARWIN_BOOTSTRAP_TIME_H\n)/$1typedef unsigned long size_t;\n/m' "$target_include/time.h"
fi
if [ "${PHASE44_RESUME:-0}" != 1 ] || [ ! -f Makefile ]; then
  for cache_dir in \
    gcc \
    libiberty \
    build-x86_64-apple-darwin \
    build-x86_64-apple-darwin/libiberty \
    fixincludes \
    gmp \
    mpfr \
    mpc \
    libcpp \
    libdecnumber \
    zlib \
    intl; do
    if [ -f "$phase35/share/darwin-bootstrap/work/build/$cache_dir/config.cache" ]; then
      mkdir -p "$cache_dir"
      grep -v '^ac_cv_env_' \
        "$phase35/share/darwin-bootstrap/work/build/$cache_dir/config.cache" \
        | grep -v -E '^(ac_cv_prog_(CC|CPP|CXX|CXXCPP|cc_|cxx_)|ac_cv_sys_largefile_CC)=' \
        > "$cache_dir/config.cache"
      chmod u+w "$cache_dir/config.cache"
    fi
  done

  ../src/configure \
    --prefix="$out" \
    --build="$target" \
    --host="$target" \
    --target="$target" \
    --with-native-system-header-dir="$target_include" \
    --with-build-sysroot="$target_include" \
    --disable-bootstrap \
    --disable-shared \
    --disable-multilib \
    --disable-nls \
    --disable-threads \
    --disable-libmudflap \
    --disable-libstdcxx-pch \
    --disable-lto \
    --enable-languages=c,c++ \
    MAKEINFO=true \
    > "$bootstrap_share/configure.stdout" \
    2> "$bootstrap_share/configure.stderr"

  mkdir -p intl
  cat > intl/Makefile <<'MAKE'
all:
install:
install-strip:
clean:
MAKE

  for prereq_dir in \
    gmp \
    mpfr \
    mpc \
    libiberty \
    build-x86_64-apple-darwin/libiberty \
    fixincludes \
    build-x86_64-apple-darwin/fixincludes \
    zlib \
    libcpp \
    libdecnumber; do
    rm -rf "$prereq_dir"
    mkdir -p "$(dirname "$prereq_dir")"
    cp -R "$phase35/share/darwin-bootstrap/work/build/$prereq_dir" "$prereq_dir"
    chmod -R u+w "$prereq_dir"
  done
  find \
    gmp \
    mpfr \
    mpc \
    libiberty \
    build-x86_64-apple-darwin/libiberty \
    fixincludes \
    build-x86_64-apple-darwin/fixincludes \
    zlib \
    libcpp \
    libdecnumber \
    -type l | while read -r header_link; do
    header_target="$(readlink "$header_link")"
    case "$header_target" in
      /nix/store/*-darwin-minimal-bootstrap-phase34-tinycc-darwin-cc-amd64/include/tcc-darwin-bootstrap/*)
        rm -f "$header_link"
        ;;
    esac
  done
  current_src_escaped="$(printf '%s\n' "$PWD/../src" | sed 's/[\/&]/\\&/g')"
  current_build_escaped="$(printf '%s\n' "$PWD" | sed 's/[\/&]/\\&/g')"
  find \
    gmp \
    mpfr \
    mpc \
    libiberty \
    build-x86_64-apple-darwin/libiberty \
    fixincludes \
    build-x86_64-apple-darwin/fixincludes \
    zlib \
    libcpp \
    libdecnumber \
    -type f \( -name Makefile -o -name '*.mk' -o -name config.status -o -name config.cache -o -name config.log \) \
    -exec perl -0pi \
      -e "s#/nix/var/nix/builds/nix-[0-9]+-[0-9]+/src#$current_src_escaped#g;" \
      -e "s#/nix/var/nix/builds/nix-[0-9]+-[0-9]+/build#$current_build_escaped#g;" \
      {} +

  mkdir -p gcc
  phase35_gcc="$phase35/share/darwin-bootstrap/work/build/gcc"
  for generated_name in \
    bversion.h \
    build/gencondmd.c \
    genrtl.h \
    gcov-iov.h \
    gtype.state \
    gtype-desc.c \
    gtype-desc.h \
    i386-builtin-types.inc \
    insn-addr.h \
    insn-attr.h \
    insn-attrtab.c \
    insn-automata.c \
    insn-codes.h \
    insn-conditions.md \
    insn-config.h \
    insn-constants.h \
    insn-emit.c \
    insn-enums.c \
    insn-extract.c \
    insn-flags.h \
    insn-modes.c \
    insn-modes.h \
    insn-opinit.c \
    insn-output.c \
    insn-peep.c \
    insn-preds.c \
    insn-recog.c \
    mddeps.mk \
    min-insn-modes.c \
    plugin-version.h \
    target-hooks-def.h \
    tm-constrs.h \
    tm-preds.h \
    tree-check.h; do
    if [ -e "$phase35_gcc/$generated_name" ] || [ -L "$phase35_gcc/$generated_name" ]; then
      rm -f "gcc/$generated_name"
      mkdir -p "$(dirname "gcc/$generated_name")"
      cp -R "$phase35_gcc/$generated_name" "gcc/$generated_name"
      chmod -R u+w "gcc/$generated_name" 2>/dev/null || true
    fi
  done
  for generated_name in "$phase35_gcc"/gt-*.h "$phase35_gcc"/gtype-*.h "$phase35_gcc"/s-*; do
    [ -e "$generated_name" ] || [ -L "$generated_name" ] || continue
    base_name="$(basename "$generated_name")"
    rm -f "gcc/$base_name"
    cp -R "$generated_name" "gcc/$base_name"
    chmod -R u+w "gcc/$base_name" 2>/dev/null || true
  done
  for generated_name in "$phase35_gcc"/build/gen*; do
    [ -f "$generated_name" ] || continue
    base_name="$(basename "$generated_name")"
    rm -f "gcc/build/$base_name"
    mkdir -p gcc/build
    cp "$generated_name" "gcc/build/$base_name"
    chmod u+w "gcc/build/$base_name" 2>/dev/null || true
    touch "gcc/build/$base_name"
  done
  if [ -f "$phase35_gcc/build/gcov-iov" ]; then
    rm -f gcc/build/gcov-iov
    mkdir -p gcc/build
    cp "$phase35_gcc/build/gcov-iov" gcc/build/gcov-iov
    chmod u+wx gcc/build/gcov-iov 2>/dev/null || true
    touch gcc/build/gcov-iov
  fi
  for generated_name in gcov gcov-dump; do
    [ -f "$phase35_gcc/$generated_name" ] || continue
    rm -f "gcc/$generated_name"
    cp "$phase35_gcc/$generated_name" "gcc/$generated_name"
    chmod u+wx "gcc/$generated_name" 2>/dev/null || true
    touch "gcc/$generated_name"
  done
  for generated_name in "$phase35_gcc"/build/*.o; do
    [ -f "$generated_name" ] || continue
    base_name="$(basename "$generated_name")"
    rm -f "gcc/build/$base_name"
    mkdir -p gcc/build
    cp "$generated_name" "gcc/build/$base_name"
    chmod u+w "gcc/build/$base_name" 2>/dev/null || true
    touch "gcc/build/$base_name"
  done

  cat >> Makefile <<'MAKE'

.PHONY: configure-gmp maybe-configure-gmp all-gmp maybe-all-gmp install-gmp maybe-install-gmp
configure-gmp maybe-configure-gmp all-gmp maybe-all-gmp install-gmp maybe-install-gmp:
	@:

.PHONY: configure-mpfr maybe-configure-mpfr all-mpfr maybe-all-mpfr install-mpfr maybe-install-mpfr
configure-mpfr maybe-configure-mpfr all-mpfr maybe-all-mpfr install-mpfr maybe-install-mpfr:
	@:

.PHONY: configure-mpc maybe-configure-mpc all-mpc maybe-all-mpc install-mpc maybe-install-mpc
configure-mpc maybe-configure-mpc all-mpc maybe-all-mpc install-mpc maybe-install-mpc:
	@:

.PHONY: configure-libiberty maybe-configure-libiberty all-libiberty maybe-all-libiberty install-libiberty maybe-install-libiberty
configure-libiberty maybe-configure-libiberty all-libiberty maybe-all-libiberty install-libiberty maybe-install-libiberty:
	@:

.PHONY: configure-build-libiberty maybe-configure-build-libiberty all-build-libiberty maybe-all-build-libiberty
configure-build-libiberty maybe-configure-build-libiberty all-build-libiberty maybe-all-build-libiberty:
	@:

.PHONY: configure-fixincludes maybe-configure-fixincludes all-fixincludes maybe-all-fixincludes install-fixincludes maybe-install-fixincludes
configure-fixincludes maybe-configure-fixincludes all-fixincludes maybe-all-fixincludes install-fixincludes maybe-install-fixincludes:
	@:

.PHONY: configure-build-fixincludes maybe-configure-build-fixincludes all-build-fixincludes maybe-all-build-fixincludes
configure-build-fixincludes maybe-configure-build-fixincludes all-build-fixincludes maybe-all-build-fixincludes:
	@:

.PHONY: configure-zlib maybe-configure-zlib all-zlib maybe-all-zlib install-zlib maybe-install-zlib
configure-zlib maybe-configure-zlib all-zlib maybe-all-zlib install-zlib maybe-install-zlib:
	@:

.PHONY: configure-libcpp maybe-configure-libcpp all-libcpp maybe-all-libcpp install-libcpp maybe-install-libcpp
configure-libcpp maybe-configure-libcpp all-libcpp maybe-all-libcpp install-libcpp maybe-install-libcpp:
	@:

.PHONY: configure-libdecnumber maybe-configure-libdecnumber all-libdecnumber maybe-all-libdecnumber install-libdecnumber maybe-install-libdecnumber
configure-libdecnumber maybe-configure-libdecnumber all-libdecnumber maybe-all-libdecnumber install-libdecnumber maybe-install-libdecnumber:
	@:
MAKE
else
  printf 'Reusing existing phase44 configure state in %s\n' "$PWD" > "$bootstrap_share/configure.resume"
fi

remove_phase34_header_symlinks() {
  local dir="$1"
  [ -d "$dir" ] || return 0
  find "$dir" -type l | while read -r link; do
    target="$(readlink "$link")"
    case "$target" in
      "$phase34"/include/tcc-darwin-bootstrap/*)
        rm -f "$link"
        ;;
    esac
  done
}

rewrite_phase34_store_refs() {
  find . -type f \( -name Makefile -o -name '*.mk' -o -name config.status -o -name config.log \) \
    -exec perl -0pi -e "s#/nix/store/[A-Za-z0-9]+-darwin-minimal-bootstrap-phase34-tinycc-darwin-cc-amd64#$phase34#g" {} +
}

fix_darwin_prereq_configs() {
  local build_dir
  if [ -f gmp/config.h ]; then
    perl -0pi -e 's@/\*\s*#\s*undef\s+HAVE_STRNLEN\s*\*/@#define HAVE_STRNLEN 1@g' gmp/config.h
  fi
  if [ -f gmp/config.cache ]; then
    perl -0pi -e 's@^ac_cv_func_strnlen=.*$@ac_cv_func_strnlen=\${ac_cv_func_strnlen=yes}@m' gmp/config.cache
  fi
  for prereq_src in ../src/gmp ../src/mpfr ../src/mpc; do
    [ -d "$prereq_src" ] || continue
    [ -f "$prereq_src/aclocal.m4" ] && touch "$prereq_src/aclocal.m4"
    [ -f "$prereq_src/Makefile.in" ] && touch "$prereq_src/Makefile.in"
    [ -f "$prereq_src/configure" ] && touch "$prereq_src/configure"
  done
  for build_dir in gmp mpfr mpc libiberty zlib libcpp libdecnumber; do
    [ -d "$build_dir" ] || continue
    [ -f "$build_dir/config.status" ] && touch "$build_dir/config.status"
    [ -f "$build_dir/Makefile" ] && touch "$build_dir/Makefile"
  done
}

rebuild_macho_archive() {
  local dir="$1"
  shift
  remove_phase34_header_symlinks "$dir"
  MAKEFLAGS= "$make_tool" -C "$dir" -j1 clean >/dev/null 2>&1 || true
  fix_darwin_prereq_configs
  env \
    GCC46_BOOTSTRAP_OBJECT_FORMAT=macho \
    GCC46_BOOTSTRAP_HOST_CC_SOURCES="${GCC46_BOOTSTRAP_HOST_CC_SOURCES:-1}" \
    GCC46_BOOTSTRAP_AS="$GCC46_BOOTSTRAP_AS" \
    GCC46_BOOTSTRAP_MACHO_CC="$GCC46_BOOTSTRAP_MACHO_CC" \
    GCC46_BOOTSTRAP_HOST_CC="$GCC46_BOOTSTRAP_HOST_CC" \
    MAKEFLAGS= \
    "$make_tool" -C "$dir" -j1 -o Makefile -o config.status \
      CC="$CC" \
      CFLAGS="$CFLAGS" \
      AR="$AR" \
      RANLIB="$RANLIB" \
      "$@"
}

install_macho_tool_wrappers() {
  [ "${GCC46_BOOTSTRAP_OBJECT_FORMAT:-elf}" = macho ] || return 0
  [ -d gcc ] || return 0
  cat > gcc/as <<EOF
#!/bin/sh
has_input=0
skip_next=0
for arg do
  if [ "\$skip_next" = 1 ]; then
    skip_next=0
    continue
  fi
  case "\$arg" in
    -arch|-o) skip_next=1 ;;
    -*) ;;
    *) has_input=1 ;;
  esac
done
if [ "\$has_input" = 0 ]; then
  exec "$GCC46_BOOTSTRAP_AS" "\$@" -
fi
exec "$GCC46_BOOTSTRAP_AS" "\$@"
EOF
  cat > gcc/collect-ld <<EOF
#!/bin/sh
exec "$GCC46_BOOTSTRAP_LD" "\$@"
EOF
  cat > gcc/ld <<EOF
#!/bin/sh
exec "$GCC46_BOOTSTRAP_LD" "\$@"
EOF
  chmod +x gcc/as gcc/collect-ld gcc/ld
}

install_output_macho_tool_wrappers() {
  [ "${GCC46_BOOTSTRAP_OBJECT_FORMAT:-elf}" = macho ] || return 0
  local runtime_dir="$out/lib/gcc/$target/$gcc_version"
  mkdir -p "$out/bin" "$runtime_dir"
  for wrapper_dir in "$out/bin" "$runtime_dir"; do
    cat > "$wrapper_dir/as" <<EOF
#!/bin/sh
has_input=0
skip_next=0
for arg do
  if [ "\$skip_next" = 1 ]; then
    skip_next=0
    continue
  fi
  case "\$arg" in
    -arch|-o) skip_next=1 ;;
    -*) ;;
    *) has_input=1 ;;
  esac
done
if [ "\$has_input" = 0 ]; then
  exec "$GCC46_BOOTSTRAP_AS" "\$@" -
fi
exec "$GCC46_BOOTSTRAP_AS" "\$@"
EOF
    cat > "$wrapper_dir/ld" <<EOF
#!/bin/sh
exec "$GCC46_BOOTSTRAP_LD" "\$@"
EOF
    cat > "$wrapper_dir/collect-ld" <<EOF
#!/bin/sh
exec "$GCC46_BOOTSTRAP_LD" "\$@"
EOF
    chmod +x "$wrapper_dir/as" "$wrapper_dir/ld" "$wrapper_dir/collect-ld"
  done
}

postprocess_macho_specs() {
  [ "${GCC46_BOOTSTRAP_OBJECT_FORMAT:-elf}" = macho ] || return 0
  [ -f gcc/specs ] || return 0
  GCC46_BOOTSTRAP_LD_FOR_PERL="$GCC46_BOOTSTRAP_LD" perl -0 -p -i \
    -e 's/%\{c\|S:%\{o\*:-auxbase-strip %\*}%\{!o\*:-auxbase %b}}/%{c|S:-auxbase-strip %g.o}/g;' \
    -e 's/%\{c\|S:-auxbase-strip %\|\.o}/%{c|S:-auxbase-strip %g.o}/g;' \
    -e 's/%\{!c:%\{!S:-auxbase %b\}\}/%{!c:%{!S:-auxbase-strip %g.s}}/g;' \
    -e 's/%\{!c:%\{!S:-auxbase-strip %\|\.s\}\}/%{!c:%{!S:-auxbase-strip %g.s}}/g;' \
    -e 's@\*linker:\x0acollect2@(qq{*linker:}.chr(10).$ENV{GCC46_BOOTSTRAP_LD_FOR_PERL})@eg' \
    gcc/specs
  if [ -f gcc/Makefile ]; then
    perl -0 -p -i -e 's/^LIBGCC2_DEBUG_CFLAGS = -g$/LIBGCC2_DEBUG_CFLAGS = -g0/m' gcc/Makefile
    perl -0 -p -i -e 's/^LIBGCOV = .*?\\n\\s*_gcov_merge_ior$/LIBGCOV =/ms' gcc/Makefile
  fi
  if [ -f gcc/libgcc.mvars ]; then
    perl -0 -p -i \
      -e 's/^LIBGCOV = .*$/LIBGCOV =/m;' \
      -e 's/^GCC_EXTRA_PARTS = .*$/GCC_EXTRA_PARTS =/m;' \
      gcc/libgcc.mvars
  fi
  if [ -f x86_64-apple-darwin/libgcc/Makefile ]; then
    local phase34_include_escaped
    phase34_include_escaped="$(printf '%s\n' "$target_include" | sed 's/[\/&]/\\&/g')"
    perl -0 -p -i \
      -e 's/^LIBGCOV = .*?\\n\\s*_gcov_merge_ior$/LIBGCOV =/ms;' \
      -e 's/^GCC_EXTRA_PARTS = .*$/GCC_EXTRA_PARTS =/m;' \
      -e "s@^(INCLUDES = .*?)(\\n\\s*-I\\\$\\(srcdir\\)/\\.\\./include \\$\\(DECNUMINC\\))@\$1\$2 -isystem $phase34_include_escaped@ms;" \
      x86_64-apple-darwin/libgcc/Makefile
  fi
}

ensure_gcc_internal_headers() {
  [ -d gcc ] || return 0
  mkdir -p gcc/include gcc/include-fixed
  for header in float.h iso646.h stdarg.h stdbool.h stddef.h varargs.h stdfix.h tgmath.h; do
    [ -f "../src/gcc/ginclude/$header" ] && cp "../src/gcc/ginclude/$header" "gcc/include/$header"
  done
  [ -f ../src/gcc/unwind-generic.h ] && cp ../src/gcc/unwind-generic.h gcc/include/unwind.h
  for header in \
    cpuid.h mmintrin.h mm3dnow.h xmmintrin.h emmintrin.h pmmintrin.h \
    tmmintrin.h ammintrin.h smmintrin.h nmmintrin.h bmmintrin.h \
    fma4intrin.h wmmintrin.h immintrin.h x86intrin.h avxintrin.h \
    xopintrin.h ia32intrin.h cross-stdarg.h lwpintrin.h popcntintrin.h \
    abmintrin.h bmiintrin.h tbmintrin.h; do
    [ -f "../src/gcc/config/i386/$header" ] && cp "../src/gcc/config/i386/$header" "gcc/include/$header"
  done
  [ -f gcc/include-fixed/syslimits.h ] || printf '#include <limits.h>\n' > gcc/include-fixed/syslimits.h
}

append_top_prereq_stubs() {
  [ -f Makefile ] || return 0
  grep -q DARWIN_BOOTSTRAP_TOP_PREREQ_STUBS Makefile && return 0
  cat >> Makefile <<'MAKE'

# DARWIN_BOOTSTRAP_TOP_PREREQ_STUBS
.PHONY: configure-gmp maybe-configure-gmp all-gmp maybe-all-gmp install-gmp maybe-install-gmp
configure-gmp maybe-configure-gmp all-gmp maybe-all-gmp install-gmp maybe-install-gmp:
	@:

.PHONY: configure-mpfr maybe-configure-mpfr all-mpfr maybe-all-mpfr install-mpfr maybe-install-mpfr
configure-mpfr maybe-configure-mpfr all-mpfr maybe-all-mpfr install-mpfr maybe-install-mpfr:
	@:

.PHONY: configure-mpc maybe-configure-mpc all-mpc maybe-all-mpc install-mpc maybe-install-mpc
configure-mpc maybe-configure-mpc all-mpc maybe-all-mpc install-mpc maybe-install-mpc:
	@:

.PHONY: configure-libiberty maybe-configure-libiberty all-libiberty maybe-all-libiberty install-libiberty maybe-install-libiberty
configure-libiberty maybe-configure-libiberty all-libiberty maybe-all-libiberty install-libiberty maybe-install-libiberty:
	@:

.PHONY: configure-build-libiberty maybe-configure-build-libiberty all-build-libiberty maybe-all-build-libiberty
configure-build-libiberty maybe-configure-build-libiberty all-build-libiberty maybe-all-build-libiberty:
	@:

.PHONY: configure-fixincludes maybe-configure-fixincludes all-fixincludes maybe-all-fixincludes install-fixincludes maybe-install-fixincludes
configure-fixincludes maybe-configure-fixincludes all-fixincludes maybe-all-fixincludes install-fixincludes maybe-install-fixincludes:
	@:

.PHONY: configure-build-fixincludes maybe-configure-build-fixincludes all-build-fixincludes maybe-all-build-fixincludes
configure-build-fixincludes maybe-configure-build-fixincludes all-build-fixincludes maybe-all-build-fixincludes:
	@:

.PHONY: configure-zlib maybe-configure-zlib all-zlib maybe-all-zlib install-zlib maybe-install-zlib
configure-zlib maybe-configure-zlib all-zlib maybe-all-zlib install-zlib maybe-install-zlib:
	@:

.PHONY: configure-libcpp maybe-configure-libcpp all-libcpp maybe-all-libcpp install-libcpp maybe-install-libcpp
configure-libcpp maybe-configure-libcpp all-libcpp maybe-all-libcpp install-libcpp maybe-install-libcpp:
	@:

.PHONY: configure-libdecnumber maybe-configure-libdecnumber all-libdecnumber maybe-all-libdecnumber install-libdecnumber maybe-install-libdecnumber
configure-libdecnumber maybe-configure-libdecnumber all-libdecnumber maybe-all-libdecnumber install-libdecnumber maybe-install-libdecnumber:
	@:
MAKE
}

make_tool=${BOOTSTRAP_MAKE:-"$phase39/bin/make"}
# The phase39 GNU Make is intentionally minimal and does not yet have a
# bootstrap-proven jobserver/pipe path.  Keep Nix builds serial by default, but
# allow impure debug runs to override both the make executable and job count.
build_cores=${BOOTSTRAP_JOBS:-1}
make_dir=${PHASE44_MAKE_DIR:-.}
make_targets=${PHASE44_TARGETS:-"all-gcc"}
gcc_make_targets=${PHASE44_GCC_TARGETS:-"xgcc cc1 c++ g++"}

sdk_path() {
  if [ -n "${PHASE44_SDK_PATH:-}" ]; then
    printf '%s\n' "$PHASE44_SDK_PATH"
  elif command -v xcrun >/dev/null 2>&1; then
    xcrun --sdk macosx --show-sdk-path
  elif [ -d /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk ]; then
    printf '%s\n' /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk
  else
    echo "phase44: set PHASE44_SDK_PATH or make xcrun visible" >&2
    exit 1
  fi
}

ensure_target_libgcc_macho() {
  [ "${PHASE44_DIRECT_TARGET_RUNTIMES:-1}" = 1 ] || return 0
  [ "$make_dir" = . ] || return 0
  [ -f gcc/xgcc ] || return 0
  if [ ! -f gcc/libgcc.mvars ] || [ ! -f gcc/tconfig.h ]; then
    if [ ! -f gcc/gsyslimits.h ] && [ -f ../src/gcc/gsyslimits.h ]; then
      cp ../src/gcc/gsyslimits.h gcc/gsyslimits.h
    fi
    MAKEFLAGS= "$make_tool" -C gcc -j1 -o Makefile -o config.status \
      MAKEINFO=true \
      CC="$CC" \
      CPP="$CPP" \
      CFLAGS="$CFLAGS" \
      CFLAGS_FOR_BUILD="$CFLAGS_FOR_BUILD" \
      CFLAGS_FOR_TARGET="$CFLAGS_FOR_TARGET" \
      CXXFLAGS_FOR_TARGET="$CXXFLAGS_FOR_TARGET" \
      AR="$AR" \
      NM="$NM" \
      RANLIB="$RANLIB" \
      STRIP="$STRIP" \
      LIPO="$LIPO" \
      OTOOL="$OTOOL" \
      libgcc-support \
      > "$bootstrap_share/make-gcc-libgcc-support.stdout" \
      2> "$bootstrap_share/make-gcc-libgcc-support.stderr"
  fi
  if [ ! -f "$target/libgcc/Makefile" ]; then
    MAKEFLAGS= "$make_tool" -j1 -o Makefile -o config.status -o maybe-all-gcc -o all-gcc \
      MAKEINFO=true \
      CC="$CC" \
      CPP="$CPP" \
      CFLAGS="$CFLAGS" \
      CFLAGS_FOR_BUILD="$CFLAGS_FOR_BUILD" \
      CFLAGS_FOR_TARGET="$CFLAGS_FOR_TARGET" \
      CXXFLAGS_FOR_TARGET="$CXXFLAGS_FOR_TARGET" \
      CRTSTUFF_T_CFLAGS="-isystem $target_include" \
      LIBGCC2_INCLUDES="-isystem $target_include" \
      AR="$AR" \
      NM="$NM" \
      RANLIB="$RANLIB" \
      STRIP="$STRIP" \
      LIPO="$LIPO" \
      OTOOL="$OTOOL" \
      configure-target-libgcc \
      > "$bootstrap_share/configure-target-libgcc.stdout" \
      2> "$bootstrap_share/configure-target-libgcc.stderr"
    postprocess_macho_specs
  fi
  MAKEFLAGS= "$make_tool" -C "$target/libgcc" -j1 \
    MAKEINFO=true \
    CRTSTUFF_T_CFLAGS="-isystem $target_include" \
    LIBGCC2_INCLUDES="-isystem $target_include" \
    AR="$AR" \
    NM="$NM" \
    RANLIB="$RANLIB" \
    STRIP="$STRIP" \
    all \
    > "$bootstrap_share/make-target-libgcc.stdout" \
    2> "$bootstrap_share/make-target-libgcc.stderr"
  if [ -f "$target/libgcc/libgcc.a" ]; then
    cp "$target/libgcc/libgcc.a" gcc/libgcc.a
    "$RANLIB" gcc/libgcc.a >/dev/null 2>&1 || true
  fi
  if [ ! -f gcc/libgcov.a ]; then
    "$AR" cr gcc/libgcov.a
    "$RANLIB" gcc/libgcov.a >/dev/null 2>&1 || true
  fi
}

write_deployment_target_wrapper() {
  local tool="$1"
  [ -x "$out/bin/$tool" ] || return 0
  mv "$out/bin/$tool" "$out/bin/$tool.real"
  cat > "$out/bin/$tool" <<EOF
#!/bin/sh
case "\${MACOSX_DEPLOYMENT_TARGET:-}" in
  10.*) ;;
  *) export MACOSX_DEPLOYMENT_TARGET=10.8 ;;
esac
self_dir=\$(CDPATH= cd -- "\$(dirname -- "\$0")" && pwd)
exec "\$self_dir/$tool.real" -B"\$self_dir/../lib/gcc/$target/$gcc_version/" "\$@"
EOF
  chmod +x "$out/bin/$tool"
}

configure_direct_libstdcxx() {
  [ -f "$target/libstdc++-v3/Makefile" ] && return 0
  mkdir -p "$target/libstdc++-v3"
  local sdk
  sdk="$(sdk_path)"
  (
    cd "$target/libstdc++-v3"
    env \
      PATH="$PWD/../../gcc:$PATH" \
      AS="$GCC46_BOOTSTRAP_AS" \
      LD="$GCC46_BOOTSTRAP_LD" \
      CC="$PWD/../../gcc/xgcc -B$PWD/../../gcc/ -B$out/$target/bin/ -B$out/$target/lib/ -isystem $target_include -isystem $out/$target/include -isystem $out/$target/sys-include" \
      CXX="$PWD/../../gcc/g++ -B$PWD/../../gcc/ -B$out/$target/bin/ -B$out/$target/lib/ -isystem $target_include -isystem $out/$target/include -isystem $out/$target/sys-include" \
      CPP="$PWD/../../gcc/xgcc -B$PWD/../../gcc/ -B$out/$target/bin/ -B$out/$target/lib/ -isystem $target_include -isystem $out/$target/include -isystem $out/$target/sys-include -E" \
      CXXCPP="$PWD/../../gcc/g++ -B$PWD/../../gcc/ -B$out/$target/bin/ -B$out/$target/lib/ -isystem $target_include -isystem $out/$target/include -isystem $out/$target/sys-include -E" \
      CFLAGS="$phase44_cflags_for_target" \
      CXXFLAGS="$phase44_cflags_for_target" \
      LDFLAGS="-nostartfiles -nodefaultlibs -L$PWD/../../gcc -lgcc -Wl,-syslibroot,$sdk -lSystem" \
      AR="$AR" \
      RANLIB="$RANLIB" \
      NM="$NM" \
      STRIP="$STRIP" \
      MAKEINFO=true \
      ../../../src/libstdc++-v3/configure \
        --prefix="$out" \
        --build="$target" \
        --host="$target" \
        --target="$target" \
        --disable-shared \
        --disable-multilib \
        --disable-nls \
        --disable-libstdcxx-pch \
        > "$bootstrap_share/configure-direct-libstdcxx.stdout" \
        2> "$bootstrap_share/configure-direct-libstdcxx.stderr"
  )
}

build_direct_libstdcxx() {
  [ "${PHASE44_DIRECT_TARGET_RUNTIMES:-1}" = 1 ] || return 0
  [ "$make_dir" = . ] || return 0
  [ -f gcc/g++ ] || return 0
  ensure_target_libgcc_macho
  configure_direct_libstdcxx
  MAKEFLAGS= "$make_tool" -C "$target/libstdc++-v3" -j1 \
    MAKEINFO=true \
    all \
    > "$bootstrap_share/make-direct-libstdcxx.stdout" \
    2> "$bootstrap_share/make-direct-libstdcxx.stderr"
  MAKEFLAGS= "$make_tool" -C "$target/libstdc++-v3" -j1 \
    MAKEINFO=true \
    install \
    > "$bootstrap_share/install-direct-libstdcxx.stdout" \
    2> "$bootstrap_share/install-direct-libstdcxx.stderr"
}

rewrite_phase34_store_refs
fix_darwin_prereq_configs
append_top_prereq_stubs
install_macho_tool_wrappers
postprocess_macho_specs

if [ "${GCC46_BOOTSTRAP_OBJECT_FORMAT:-elf}" = macho ] && [ "${PHASE44_REBUILD_MACHO_PREREQS:-0}" = 1 ]; then
  for prereq_name in ${PHASE44_REBUILD_MACHO_PREREQS_LIST:-libiberty zlib gmp mpfr mpc libcpp libdecnumber}; do
    case "$prereq_name" in
      libiberty|zlib|libdecnumber)
        rebuild_macho_archive "$prereq_name" all
        ;;
      libcpp)
        rebuild_macho_archive libcpp CFLAGS="$CFLAGS -Wno-implicit-function-declaration" all
        ;;
      gmp)
        rebuild_macho_archive gmp CFLAGS="$CFLAGS -DHAVE_STRNLEN=1" all
        ;;
      mpfr)
        rebuild_macho_archive mpfr \
          CPPFLAGS="-I$PWD/gmp -DUINTMAX_MAX=18446744073709551615ULL -DINTMAX_MAX=9223372036854775807LL -DINTMAX_MIN='(-9223372036854775807LL - 1)'" \
          LDFLAGS="-L$PWD/gmp/.libs" \
          libmpfr.la
        ;;
      mpc)
        rebuild_macho_archive mpc/src \
          CPPFLAGS="-DNULL=0 -I$PWD/gmp -I$PWD/mpfr" \
          LDFLAGS="-L$PWD/gmp/.libs -L$PWD/mpfr/.libs" \
          libmpc.la
        ;;
      *)
        echo "unknown phase44 Mach-O prerequisite: $prereq_name" >&2
        exit 1
        ;;
    esac
  done
  find gcc -name '*.o' -type f ! -path 'gcc/build/*' -delete
fi

if [ "$make_dir" != . ] && [ ! -f "$make_dir/Makefile" ]; then
  MAKEFLAGS= "$make_tool" -j1 \
    MAKEINFO=true \
    CC="$CC" \
    CPP="$CPP" \
    CFLAGS="$CFLAGS" \
    CFLAGS_FOR_BUILD="$CFLAGS_FOR_BUILD" \
    CFLAGS_FOR_TARGET="$CFLAGS_FOR_TARGET" \
    CXXFLAGS_FOR_TARGET="$CXXFLAGS_FOR_TARGET" \
    AR="$AR" \
    NM="$NM" \
    RANLIB="$RANLIB" \
    STRIP="$STRIP" \
    LIPO="$LIPO" \
    OTOOL="$OTOOL" \
    "configure-$make_dir" \
    > "$bootstrap_share/configure-$make_dir.stdout" \
    2> "$bootstrap_share/configure-$make_dir.stderr"
fi

if [ "${PHASE44_SKIP_MAIN_MAKE:-0}" != 1 ]; then
  if [ "$make_dir" = . ] && [ "$make_targets" = "all-gcc" ] && [ "${PHASE44_DIRECT_GCC_MAKE:-1}" = 1 ]; then
    if [ ! -f gcc/Makefile ]; then
      MAKEFLAGS= "$make_tool" -j1 \
        MAKEINFO=true \
        CC="$CC" \
        CPP="$CPP" \
        CFLAGS="$CFLAGS" \
        CFLAGS_FOR_BUILD="$CFLAGS_FOR_BUILD" \
        CFLAGS_FOR_TARGET="$CFLAGS_FOR_TARGET" \
        CXXFLAGS_FOR_TARGET="$CXXFLAGS_FOR_TARGET" \
        AR="$AR" \
        NM="$NM" \
        RANLIB="$RANLIB" \
        STRIP="$STRIP" \
        LIPO="$LIPO" \
        OTOOL="$OTOOL" \
        configure-gcc \
        > "$bootstrap_share/configure-gcc.stdout" \
        2> "$bootstrap_share/configure-gcc.stderr"
    fi
    MAKEFLAGS= "$make_tool" -C gcc -j"$build_cores" \
      MAKEINFO=true \
      CC="$CC" \
      CPP="$CPP" \
      CFLAGS="$CFLAGS" \
      CFLAGS_FOR_BUILD="$CFLAGS_FOR_BUILD" \
      CFLAGS_FOR_TARGET="$CFLAGS_FOR_TARGET" \
      CXXFLAGS_FOR_TARGET="$CXXFLAGS_FOR_TARGET" \
      AR="$AR" \
      NM="$NM" \
      RANLIB="$RANLIB" \
      STRIP="$STRIP" \
      LIPO="$LIPO" \
      OTOOL="$OTOOL" \
      $gcc_make_targets \
      > "$bootstrap_share/make.stdout" \
      2> "$bootstrap_share/make.stderr"
  else
    MAKEFLAGS= "$make_tool" -C "$make_dir" -j"$build_cores" \
      MAKEINFO=true \
      CC="$CC" \
      CPP="$CPP" \
      CFLAGS="$CFLAGS" \
      CFLAGS_FOR_BUILD="$CFLAGS_FOR_BUILD" \
      CFLAGS_FOR_TARGET="$CFLAGS_FOR_TARGET" \
      CXXFLAGS_FOR_TARGET="$CXXFLAGS_FOR_TARGET" \
      AR="$AR" \
      NM="$NM" \
      RANLIB="$RANLIB" \
      STRIP="$STRIP" \
      LIPO="$LIPO" \
      OTOOL="$OTOOL" \
      $make_targets \
      > "$bootstrap_share/make.stdout" \
      2> "$bootstrap_share/make.stderr"
  fi
else
  printf 'Skipped main make in resumed phase44 tree\n' > "$bootstrap_share/make.skipped"
fi

install_macho_tool_wrappers
postprocess_macho_specs
ensure_gcc_internal_headers
build_direct_libstdcxx

if [ "${PHASE44_SKIP_INSTALL:-0}" = 1 ] || [ "$make_dir" != . ] || [ "$make_targets" != "all-gcc" ]; then
  exit 0
fi

mkdir -p "$out/bin" "$out/lib/gcc/$target/$gcc_version" "$out/$target/include" "$out/$target/sys-include"
cp -R "$target_include/." "$out/$target/include/"
cp gcc/xgcc "$out/bin/gcc"
cp gcc/g++ "$out/bin/g++"
install_output_macho_tool_wrappers
write_deployment_target_wrapper gcc
write_deployment_target_wrapper g++
cp gcc/cc1 "$out/lib/gcc/$target/$gcc_version/cc1"
cp gcc/cc1plus "$out/lib/gcc/$target/$gcc_version/cc1plus"
cp gcc/specs "$out/lib/gcc/$target/$gcc_version/specs"
cp -R gcc/include "$out/lib/gcc/$target/$gcc_version/include"
cp -R gcc/include-fixed "$out/lib/gcc/$target/$gcc_version/include-fixed"
cp gcc/libgcc.a "$out/lib/gcc/$target/$gcc_version/libgcc.a"
cp gcc/libgcov.a "$out/lib/gcc/$target/$gcc_version/libgcov.a"
chmod +x "$out/bin/gcc" "$out/bin/g++" "$out/lib/gcc/$target/$gcc_version/cc1" "$out/lib/gcc/$target/$gcc_version/cc1plus"

test -x "$out/bin/gcc"
test -x "$out/bin/g++"
"$out/bin/g++" --version > "$bootstrap_share/g++-version.stdout"

cat > cxx-smoke.cc <<'CC'
int helper(int x) { return x + 40; }
int main() { return helper(2); }
CC
"$out/bin/g++" -S cxx-smoke.cc -o "$bootstrap_share/cxx-smoke.s" \
  > "$bootstrap_share/cxx-smoke.stdout" \
  2> "$bootstrap_share/cxx-smoke.stderr"
test -s "$bootstrap_share/cxx-smoke.s"
