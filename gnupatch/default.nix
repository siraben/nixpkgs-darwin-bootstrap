{
  runCommand,
  gnupatchVersion,
  gnupatchTarball,
  phase34-tinycc-darwin-cc,
  ...
}:
runCommand "phase40-gnupatch-${gnupatchVersion}" { } ''
  mkdir -p $out/bin $out/share/darwin-bootstrap

  tar -xzf ${gnupatchTarball}
  cd patch-${gnupatchVersion}

  cat > config.h <<'H'
  H

  export CC=${phase34-tinycc-darwin-cc}/bin/tcc-darwin-cc
  export CFLAGS="-I. -DNULL=0 -DHAVE_DECL_GETENV -DHAVE_DECL_MALLOC -DHAVE_DIRENT_H -DHAVE_LIMITS_H -DHAVE_GETEUID -DHAVE_MKTEMP -DPACKAGE_BUGREPORT= -Ded_PROGRAM=\"/nullop\" -Dmbstate_t=int -DRETSIGTYPE=int -DHAVE_MKDIR -DHAVE_RMDIR -DHAVE_FCNTL_H -DPACKAGE_NAME=\"patch\" -DPACKAGE_VERSION=\"${gnupatchVersion}\" -DHAVE_MALLOC -DHAVE_REALLOC -DSTDC_HEADERS -DHAVE_STRING_H -DHAVE_STDLIB_H -DHAVE_VPRINTF"

  sources='addext.c argmatch.c backupfile.c basename.c dirname.c getopt.c getopt1.c inp.c maketime.c partime.c patch.c pch.c quote.c quotearg.c quotesys.c util.c version.c xmalloc.c error.c'
  objects=
  for source in $sources; do
    object="$(basename "$source" .c).o"
    $CC $CFLAGS -c "$source" -o "$object" > "$object.stdout" 2> "$object.stderr"
    objects="$objects $object"
  done

  $CC $CFLAGS -o patch $objects > patch-link.stdout 2> patch-link.stderr
  ./patch --version > patch-version.stdout 2> patch-version.stderr
  grep -q 'patch ${gnupatchVersion}' patch-version.stdout
  printf 'a\n' > patch-smoke-file
  cat > patch-smoke.diff <<'P'
  --- patch-smoke-file
  +++ patch-smoke-file
  @@ -1 +1 @@
  -a
  +b
  P
  ./patch -p0 -i patch-smoke.diff > patch-smoke.stdout 2> patch-smoke.stderr
  grep -q '^b$' patch-smoke-file

  install -Dm755 patch $out/bin/patch
  cp patch-version.stdout patch-version.stderr patch-smoke.stdout patch-smoke.stderr \
    patch-link.stdout patch-link.stderr \
    $out/share/darwin-bootstrap/
''
