#!/bin/sh
## 45-gnumake — build GNU Make 4.4.1 via tcc-darwin-cc.
##
## The chain has had no `make` until now; every earlier step is driven by
## plain shell.  The gcc-4.6 and gcc-10 builds (steps 48-55) are
## Makefile-driven, so a chain-built GNU Make is the prerequisite for
## everything past this point.  Mirrors nix/gnumake/default.nix: applies
## ~15 source text edits to remove Linux-isms and features the minimal
## chain libc lacks, then compiles 30 C files individually and links.
##
## Runs:    chain tcc-darwin-cc from step 44 (all compilation + linking);
##          host /usr/bin/perl for the patch_replace text edits and for
##          scripts/phase39-patch-job.sh — trust boundary (source text
##          edits only, no code generation);
##          Apple tar/grep/install for orchestration.
## Inputs:  tarballs/make-4.4.1.tar.gz (pinned SHA-256, fetched by
##          scripts/fetch-sources.sh);
##          scripts/phase39-patch-job.sh (symlink to
##          nix/scripts/gnumake/phase39-patch-job.sh).
## Outputs: $TARGET/bin/make; scratch tree $TARGET/work/gnumake.
## Verifies: ./make --version output contains "GNU Make" (the freshly
##          linked Mach-O executes and reaches main).
## Trust:   host perl edits C source text; every byte of the resulting
##          binary comes from the chain compiler and linker.
set -eu

tarball="$ROOT/tarballs/make-4.4.1.tar.gz"
test -f "$tarball" || { echo "missing $tarball" >&2; exit 1; }

work="$TARGET/work/gnumake"
rm -rf "$work"
mkdir -p "$work"
cd "$work"

tar -xzf "$tarball"
cd make-4.4.1

## Apply the patches (mirrors substituteInPlace from Nix).  Use awk/sed
## with sentinels to detect the original pattern is present, like Nix's
## --replace-fail.
patch_replace() {
    file="$1"; old="$2"; new="$3"
    if ! grep -qF -- "$old" "$file"; then
        echo "patch: missing pattern in $file: $old" >&2
        exit 1
    fi
    ## Use perl with \Q...\E to make $old a literal string regex.
    OLD="$old" NEW="$new" /usr/bin/perl -i -pe '
      $o = $ENV{OLD}; $n = $ENV{NEW};
      s/\Q$o\E/$n/g;
    ' "$file"
}

## Drop hardcoded Linux/FHS include and library search directories; the
## bootstrap has no /usr/gnu and must never read host /usr/include.
patch_replace src/read.c '    "/usr/gnu/include",' ""
patch_replace src/read.c '    "/usr/local/include",' ""
patch_replace src/read.c '    "/usr/include",' ""
patch_replace src/remake.c '      "/lib",' ""
patch_replace src/remake.c '      "/usr/lib",' ""
## The chain libc lacks the W* wait-status macros and getloadavg support;
## report no signal/coredump and a load average of 0.
patch_replace src/job.c 'exit_sig = WIFSIGNALED (status) ? WTERMSIG (status) : 0;' 'exit_sig = 0;'
patch_replace src/job.c 'coredump = WCOREDUMP (status);' 'coredump = 0;'
patch_replace src/job.c '  /* Find the real system load average.  */' '  return 0; /* Find the real system load average.  */'
## main.c: skip putenv (chain libc gap), record the current directory as
## the literal "." (always valid for the bootstrap's relative paths), and
## jump over the "update makefiles, then re-exec" machinery — the
## bootstrap never regenerates a makefile.
patch_replace src/main.c '              putenv (b);' '              (void) b;'
patch_replace src/main.c '  if (getcwd (current_directory, GET_PATH_MAX) == 0)' '  if (strcpy (current_directory, "."), 0)'
patch_replace src/main.c '      DB (DB_BASIC, (_("Updating makefiles....\n")));' '      goto skip_bootstrap_remake_makefiles;'
patch_replace src/main.c "  /* Set up 'MAKEFLAGS' again for the normal targets.  */" "skip_bootstrap_remake_makefiles: /* Set up 'MAKEFLAGS' again for the normal targets.  */"

## Replace job.c's posix_spawn child-launch block with classic fork/exec
## (the chain libc has no posix_spawn).  The script is a symlink to
## nix/scripts/gnumake/phase39-patch-job.sh and uses host perl for the
## multi-line splice — trust boundary, text edit only.
/bin/bash "$ROOT/scripts/phase39-patch-job.sh"

## misc.c: test mktemp's result with strcmp against "" (no char deref of
## the call result) and disable the S_ISDIR check.  glob.c: alloca is
## mapped to malloc via -Dalloca=malloc below, so the extern char
## *alloca() declaration must go.
patch_replace src/misc.c "if (*mktemp (path) == '\0')" 'if (!strcmp (mktemp (path), ""))'
patch_replace src/misc.c 'else if (! S_ISDIR (st.st_mode))' 'else if (0 && ! S_ISDIR (st.st_mode))'
patch_replace lib/glob.c 'extern char *alloca ();' '/* bootstrap: alloca macro maps to malloc */'

## No autoconf run: assemble config.h from the shipped templates and use
## the bundled glob/fnmatch .in.h headers verbatim.
cat src/mkconfig.h src/mkcustom.h > src/config.h
cp lib/glob.in.h lib/glob.h
cp lib/fnmatch.in.h lib/fnmatch.h


## Move the HAVE_*/feature macros from -D into config.h.  tcc-darwin-cc's
## integrated preprocessor can misbehave when ~40+ command-line -D macros
## are present together (manifested as a spurious makeint.h mode_t
## redefinition error).  As #defines inside config.h they go through a
## more reliable path.  (NB: this is unrelated to the libiberty
## stack-overflow, whose real cause was self-recursive 64-bit int<->float
## helpers in the tcc libc — see docs/STATUS.md.)
cat >> src/config.h <<'BOOTCFG'
#ifndef BOOT_EXTRA_DEFS
#define BOOT_EXTRA_DEFS 1
#define HAVE_ATEXIT 1
#define HAVE_DIRENT_H 1
#define HAVE_DUP2 1
#define HAVE_FCNTL_H 1
#define HAVE_FDOPEN 1
#define HAVE_GETCWD 1
#define HAVE_GETTIMEOFDAY 1
#define HAVE_INTTYPES_H 1
#define HAVE_ISATTY 1
#define HAVE_LIMITS_H 1
#define HAVE_LOCALE_H 1
#define HAVE_MEMORY_H 1
#define HAVE_MKTEMP 1
#define HAVE_SETVBUF 1
#define HAVE_SIGSETMASK 1
#define HAVE_STDINT_H 1
#define HAVE_STDLIB_H 1
#define HAVE_STRDUP 1
#define HAVE_STRERROR 1
#define HAVE_STRINGS_H 1
#define HAVE_STRING_H 1
#define HAVE_STRTOLL 1
#define HAVE_SYS_FILE_H 1
#define HAVE_SYS_PARAM_H 1
#define HAVE_SYS_RESOURCE_H 1
#define HAVE_SYS_SELECT_H 1
#define HAVE_SYS_STAT_H 1
#define HAVE_SYS_TIME_H 1
#define HAVE_SYS_WAIT_H 1
#define HAVE_TTYNAME 1
#define HAVE_UMASK 1
#define HAVE_UNISTD_H 1
#define HAVE_WAITPID 1
#define STDC_HEADERS 1
#define MAKE_SYMLINKS 1
#endif
BOOTCFG

CC="$TARGET/bin/tcc-darwin-cc"
CFLAGS='-I./src -I./lib -DHAVE_CONFIG_H -DLIBDIR="/fake-libdir" -DLOCALEDIR="/fake-locale" -DPOSIX=1 -DNO_ARCHIVES=1 -DNO_OUTPUT_SYNC=1 -DO_TMPFILE=020000000 -DFILE_TIMESTAMP_HI_RES=0 -Dalloca=malloc -DHAVE_DECL_BSD_SIGNAL=0 -DHAVE_DECL_GETLOADAVG=0 -DHAVE_DECL_SYS_SIGLIST=0 -DHAVE_DECL__SYS_SIGLIST=0 -DHAVE_DECL___SYS_SIGLIST=0 -DPATH_SEPARATOR_CHAR=0x3a -DSCCS_GET="get"'

sources='src/commands.c src/default.c src/dir.c src/expand.c src/file.c src/function.c src/getopt.c src/getopt1.c src/guile.c src/hash.c src/implicit.c src/job.c src/load.c src/loadapi.c src/main.c src/misc.c src/output.c src/read.c src/remake.c src/rule.c src/shuffle.c src/signame.c src/strcache.c src/variable.c src/version.c src/vpath.c lib/fnmatch.c lib/glob.c src/remote-stub.c src/posixos.c'
objects=
for source in $sources; do
    object="$(basename "$source" .c).o"
    "$CC" $CFLAGS -c "$source" -o "$object"
    objects="$objects $object"
done

"$CC" $CFLAGS -o make $objects
## Smoke test: the new binary must execute and identify itself.
./make --version > make-version.stdout
grep -q 'GNU Make' make-version.stdout

install -m755 make "$TARGET/bin/make"
echo "make built: $(./make --version | head -1)"
