{
  runCommand,
  perl,
  root,
  gnumakeVersion,
  gnumakeTarball,
  tinycc-darwin-cc,
  ...
}:
runCommand "gnumake-${gnumakeVersion}" {
  nativeBuildInputs = [ perl ];
} ''
  mkdir -p $out/bin $out/share/darwin-bootstrap

  tar -xzf ${gnumakeTarball}
  cd make-${gnumakeVersion}

  substituteInPlace src/read.c \
    --replace-fail '    "/usr/gnu/include",' "" \
    --replace-fail '    "/usr/local/include",' "" \
    --replace-fail '    "/usr/include",' ""
  substituteInPlace src/remake.c \
    --replace-fail '      "/lib",' "" \
    --replace-fail '      "/usr/lib",' ""
  substituteInPlace src/job.c \
    --replace-fail '#if defined(__MSDOS__) || defined(VMS) || defined(_AMIGA) || defined(__riscos__)' '#if defined(__MSDOS__) || defined(VMS) || defined(_AMIGA) || defined(__riscos__)'
  substituteInPlace src/job.c \
    --replace-fail 'exit_sig = WIFSIGNALED (status) ? WTERMSIG (status) : 0;' 'exit_sig = 0;' \
    --replace-fail 'coredump = WCOREDUMP (status);' 'coredump = 0;'
  substituteInPlace src/job.c \
    --replace-fail '  /* Find the real system load average.  */' '  return 0; /* Find the real system load average.  */'
  substituteInPlace src/main.c \
    --replace-fail '              putenv (b);' '              (void) b;'
  substituteInPlace src/main.c \
    --replace-fail '      DB (DB_BASIC, (_("Updating makefiles....\n")));' '      goto skip_bootstrap_remake_makefiles;'
  substituteInPlace src/main.c \
    --replace-fail "  /* Set up 'MAKEFLAGS' again for the normal targets.  */" "skip_bootstrap_remake_makefiles: /* Set up 'MAKEFLAGS' again for the normal targets.  */"
  bash ${root + "/scripts/gnumake/phase39-patch-job.sh"}
  substituteInPlace src/misc.c \
    --replace-fail "if (*mktemp (path) == '\\0')" 'if (!strcmp (mktemp (path), ""))'
  substituteInPlace src/misc.c \
    --replace-fail 'else if (! S_ISDIR (st.st_mode))' 'else if (0 && ! S_ISDIR (st.st_mode))'
  substituteInPlace lib/glob.c \
    --replace-fail 'extern char *alloca ();' '/* bootstrap: alloca macro maps to malloc */'

  cat src/mkconfig.h src/mkcustom.h > src/config.h
  cp lib/glob.in.h lib/glob.h
  cp lib/fnmatch.in.h lib/fnmatch.h

  export CC=${tinycc-darwin-cc}/bin/tcc-darwin-cc
  export CFLAGS="-I./src -I./lib -DHAVE_CONFIG_H -DLIBDIR=\"$out/lib\" -DLOCALEDIR=\"/fake-locale\" -DPOSIX=1 -DNO_ARCHIVES=1 -DNO_OUTPUT_SYNC=1 -DO_TMPFILE=020000000 -DFILE_TIMESTAMP_HI_RES=0 -Dalloca=malloc -DHAVE_ATEXIT -DHAVE_DECL_BSD_SIGNAL=0 -DHAVE_DECL_GETLOADAVG=0 -DHAVE_DECL_SYS_SIGLIST=0 -DHAVE_DECL__SYS_SIGLIST=0 -DHAVE_DECL___SYS_SIGLIST=0 -DHAVE_DIRENT_H -DHAVE_DUP2 -DHAVE_FCNTL_H -DHAVE_FDOPEN -DHAVE_GETCWD -DHAVE_GETTIMEOFDAY -DHAVE_INTTYPES_H -DHAVE_ISATTY -DHAVE_LIMITS_H -DHAVE_LOCALE_H -DHAVE_MEMORY_H -DHAVE_MKTEMP -DHAVE_SETVBUF -DHAVE_SIGSETMASK -DHAVE_STDINT_H -DHAVE_STDLIB_H -DHAVE_STRDUP -DHAVE_STRERROR -DHAVE_STRINGS_H -DHAVE_STRING_H -DHAVE_STRTOLL -DHAVE_SYS_FILE_H -DHAVE_SYS_PARAM_H -DHAVE_SYS_RESOURCE_H -DHAVE_SYS_SELECT_H -DHAVE_SYS_STAT_H -DHAVE_SYS_TIME_H -DHAVE_SYS_WAIT_H -DHAVE_TTYNAME -DHAVE_UMASK -DHAVE_UNISTD_H -DHAVE_WAITPID -DMAKE_SYMLINKS -DPATH_SEPARATOR_CHAR=0x3a"
  export CFLAGS="$CFLAGS -DSCCS_GET=\"get\" -DSTDC_HEADERS"

  sources='src/commands.c src/default.c src/dir.c src/expand.c src/file.c src/function.c src/getopt.c src/getopt1.c src/guile.c src/hash.c src/implicit.c src/job.c src/load.c src/loadapi.c src/main.c src/misc.c src/output.c src/read.c src/remake.c src/rule.c src/shuffle.c src/signame.c src/strcache.c src/variable.c src/version.c src/vpath.c lib/fnmatch.c lib/glob.c src/remote-stub.c src/posixos.c'
  objects=
  for source in $sources; do
    object="$(basename "$source" .c).o"
    $CC $CFLAGS -c "$source" -o "$object" > "$object.stdout" 2> "$object.stderr"
    objects="$objects $object"
  done

  $CC $CFLAGS -o make $objects > make-link.stdout 2> make-link.stderr
  ./make --version > make-version.stdout 2> make-version.stderr
  grep -q 'GNU Make' make-version.stdout
  test ! -s make-version.stderr
  cp ${root + "/gnumake/fixtures/default-bootstrap-smoke.mk"} bootstrap-smoke.mk
  MAKEFLAGS= ./make -j2 -f bootstrap-smoke.mk > make-smoke.stdout 2> make-smoke.stderr
  grep -q serial serial.out
  grep -q a parallel.out
  grep -q b parallel.out

  install -Dm755 make $out/bin/make
  cp make-version.stdout make-version.stderr make-smoke.stdout make-smoke.stderr \
    serial.out parallel.out \
    make-link.stdout make-link.stderr \
    $out/share/darwin-bootstrap/
''
