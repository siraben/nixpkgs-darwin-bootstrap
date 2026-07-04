{
  runCommand,
  lib,
  source,
  cctools,
  coreutilsVersion,
  coreutilsTarball,
  coreutilsMakefile,
  coreutilsPatches,
  tinycc-darwin-cc,
  bootstrap-gnumake,
  gnupatch,
  ...
}:
runCommand "coreutils-${coreutilsVersion}" { } ''
  mkdir -p $out/bin $out/share/darwin-bootstrap

  tar -xzf ${coreutilsTarball}
  cd coreutils-${coreutilsVersion}

  for patch_file in ${lib.escapeShellArgs coreutilsPatches}; do
    ${gnupatch}/bin/patch -Np0 -i "$patch_file"
  done

  : > config.h
  cp lib/fnmatch_.h lib/fnmatch.h
  substituteInPlace lib/fnmatch.h \
    --replace-fail '# if !defined _POSIX_C_SOURCE || _POSIX_C_SOURCE < 2 || defined _GNU_SOURCE' '# if 1'
  cp lib/ftw_.h lib/ftw.h
  cp lib/search_.h lib/search.h
  rm src/dircolors.h

  {
    echo 'include ${coreutilsMakefile}'
    for source in src/*.c lib/*.c; do
      object="''${source%.c}.o"
      printf '%s: %s\n' "$object" "$source"
      printf '\t$(CC) $(CFLAGS) -c -o $@ $<\n\n'
    done
  } > bootstrap-coreutils.mk

  export CC=${tinycc-darwin-cc}/bin/tcc-darwin-cc
  MAKEFLAGS= ${bootstrap-gnumake}/bin/make -f bootstrap-coreutils.mk \
    CC="$CC -I lib -DNULL=0 -D_GNU_SOURCE=1 -DHAVE_SYS_TYPES_H=1 -DFILESYSTEM_PREFIX_LEN\(Filename\)=0 -DISSLASH\(C\)=\(\(C\)==47\)" \
    AR=${cctools}/bin/ar \
    PREFIX="$out" \
    > coreutils-build.stdout \
    2> coreutils-build.stderr

  ./src/echo "Hello coreutils!" > coreutils-smoke.stdout 2> coreutils-smoke.stderr
  grep -q "Hello coreutils!" coreutils-smoke.stdout

  MAKEFLAGS= ${bootstrap-gnumake}/bin/make -f bootstrap-coreutils.mk install \
    PREFIX="$out" \
    > coreutils-install.stdout \
    2> coreutils-install.stderr

  cp coreutils-build.stdout coreutils-build.stderr \
    coreutils-smoke.stdout coreutils-smoke.stderr \
    coreutils-install.stdout coreutils-install.stderr \
    $out/share/darwin-bootstrap/
''
