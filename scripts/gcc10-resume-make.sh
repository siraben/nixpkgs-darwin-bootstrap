#!/bin/sh
# Resume gcc-10 `make all-gcc` in the existing build dir with the full
# chain toolchain env. Codifies the env that has otherwise been ad-hoc.
#
# Maintainer tool: re-enters the step-55 build after an interruption or a
# late-step fix without rebuilding from scratch (build.sh's driver path is
# step 55 itself, which shares this env via scripts/gcc10-env.sh).  Env
# contract: ROOT optional (self-locates); TARGET defaults to $ROOT/target.
# Toolchain settings are shared with steps 54/55 via gcc10-env.sh.
# Trust: chain make/tcc/g++/boot-ar do all translation; host actions are
# mtime normalization (touch) and one sed Makefile text edit, both
# documented at their sites below.
set -eu

ROOT="${ROOT:-$(cd -- "$(dirname -- "$0")/.." && pwd)}"
. "$ROOT/scripts/gcc10-env.sh"
B="$GCC10_BUILD"

# NB: we deliberately do NOT delete any sub-configure config.cache/config.status
# here. The depmode probe is handled for good (config.site pins the host subdirs;
# the g++ wrapper's -MF support makes the build-* probe pass). Deleting
# gcc/config.status while gcc/Makefile persists makes the gcc subdir's
# "config.status:" rule abort with "You must configure gcc" once the build
# advances into gcc proper. Leave the configured state intact and just resume.

# Normalize source-tree mtimes to one fixed past timestamp. The host clock has
# drifted behind the checked-out file mtimes ("modification time in the future"),
# so make sees Makefile.am newer than Makefile.in and tries to re-run automake
# (which is not installed) -> "automake-1.17: command not found". Equal mtimes
# across the tree disable the entire maintainer-mode regen chain (configure:
# configure.ac, Makefile.in: Makefile.am, aclocal.m4: *.m4 all become "not newer").
if [ -d "$GCC10_SRC" ]; then
  find "$GCC10_SRC" -print0 | xargs -0 touch -t 202601010000 2>/dev/null || true
fi

# Force build-side archives to use boot-ar. The build-x86_64-apple-darwin/libcpp
# Makefile hardcodes `AR = ar` (Apple's), which silently produces an empty
# __.SYMDEF-only archive from our ELF objects -> genmatch fails to link
# ("Target label _ZNK13rich_location7get_locEj is not valid"). A command-line
# AR_FOR_BUILD override does NOT reach it: the top Makefile only EXPORTS
# AR=$(AR_FOR_BUILD) into the sub-make environment, and a Makefile `AR =`
# assignment beats an environment variable. So patch the generated Makefile
# directly (idempotent; the regex no-ops once already pointing at boot-ar).
for mk in "$B"/build-*/libcpp/Makefile; do
  [ -f "$mk" ] && sed -i.bak "s|^AR = ar\$|AR = $AR|" "$mk"
done

cd "$B"
exec "$MAKE" all-gcc -j1 MAKEINFO=true \
  NATIVE_SYSTEM_HEADER_DIR="$GCC10_SYS" \
  CPP="$CPP" CXXCPP="$CXXCPP" AR="$AR" RANLIB="$RANLIB" NM="$NM" \
  AR_FOR_BUILD="$AR_FOR_BUILD" RANLIB_FOR_BUILD="$RANLIB_FOR_BUILD" \
  CFLAGS="$CFLAGS" CXXFLAGS="$CXXFLAGS"
