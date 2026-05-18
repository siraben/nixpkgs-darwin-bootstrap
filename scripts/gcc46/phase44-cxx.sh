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
	@cp gsyslimits.h include-fixed/syslimits.h
	$(STAMP) stmp-fixinc
MAKE
fi

if ! grep -q DARWIN_BOOTSTRAP_GCC_FIXINC_STAMP src/gcc/Makefile.in; then
  cat >> src/gcc/Makefile.in <<'MAKE'

# DARWIN_BOOTSTRAP_GCC_FIXINC_STAMP
stmp-fixinc:
	@mkdir -p include-fixed
	@cp gsyslimits.h include-fixed/syslimits.h
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
MAKE
fi

if ! grep -q DARWIN_BOOTSTRAP_GCC_GENERATOR_BINARIES src/gcc/Makefile.in; then
  cat >> src/gcc/Makefile.in <<'MAKE'

# DARWIN_BOOTSTRAP_GCC_GENERATOR_BINARIES
$(genprog:%=build/gen%$(build_exeext)):
	@test -f $@
MAKE
fi

cd build
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
    --with-native-system-header-dir="$phase34/include/tcc-darwin-bootstrap" \
    --with-build-sysroot="$phase34/include/tcc-darwin-bootstrap" \
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

  mkdir -p gcc
  phase35_gcc="$phase35/share/darwin-bootstrap/work/build/gcc"
  for generated_name in \
    build/gencondmd.c \
    genrtl.h \
    gtype.state \
    gtype-desc.c \
    gtype-desc.h \
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

rebuild_macho_archive() {
  local dir="$1"
  shift
  remove_phase34_header_symlinks "$dir"
  MAKEFLAGS= "$make_tool" -C "$dir" -j1 clean >/dev/null 2>&1 || true
  env \
    GCC46_BOOTSTRAP_OBJECT_FORMAT=macho \
    GCC46_BOOTSTRAP_HOST_CC_SOURCES="${GCC46_BOOTSTRAP_HOST_CC_SOURCES:-1}" \
    GCC46_BOOTSTRAP_AS="$GCC46_BOOTSTRAP_AS" \
    GCC46_BOOTSTRAP_MACHO_CC="$GCC46_BOOTSTRAP_MACHO_CC" \
    GCC46_BOOTSTRAP_HOST_CC="$GCC46_BOOTSTRAP_HOST_CC" \
    MAKEFLAGS= \
    "$make_tool" -C "$dir" -j1 \
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
  chmod +x gcc/as gcc/collect-ld
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
    perl -0 -p -i \
      -e 's/^LIBGCOV = .*?\\n\\s*_gcov_merge_ior$/LIBGCOV =/ms;' \
      -e 's/^GCC_EXTRA_PARTS = .*$/GCC_EXTRA_PARTS =/m;' \
      x86_64-apple-darwin/libgcc/Makefile
  fi
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
make_targets=${PHASE44_TARGETS:-"all-gcc all-target-libstdc++-v3"}

rewrite_phase34_store_refs
append_top_prereq_stubs
install_macho_tool_wrappers
postprocess_macho_specs

if [ "${GCC46_BOOTSTRAP_OBJECT_FORMAT:-elf}" = macho ] && [ "${PHASE44_REBUILD_MACHO_PREREQS:-0}" = 1 ]; then
  rebuild_macho_archive libiberty all
  rebuild_macho_archive zlib all
  rebuild_macho_archive gmp all
  rebuild_macho_archive mpfr \
    CPPFLAGS="-I$PWD/gmp" \
    LDFLAGS="-L$PWD/gmp/.libs" \
    all
  rebuild_macho_archive mpc \
    CPPFLAGS="-DNULL=0 -I$PWD/gmp -I$PWD/mpfr" \
    LDFLAGS="-L$PWD/gmp/.libs -L$PWD/mpfr/.libs" \
    all
  rebuild_macho_archive libcpp all
  rebuild_macho_archive libdecnumber all
  find gcc -name '*.o' -type f -delete
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

install_macho_tool_wrappers
postprocess_macho_specs

if [ "${PHASE44_SKIP_INSTALL:-0}" = 1 ] || [ "$make_dir" != . ] || [ "$make_targets" != "all-gcc all-target-libstdc++-v3" ]; then
  exit 0
fi

MAKEFLAGS= "$make_tool" -j"$build_cores" \
  MAKEINFO=true \
  install-gcc install-target-libstdc++-v3 \
  > "$bootstrap_share/install.stdout" \
  2> "$bootstrap_share/install.stderr"

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
