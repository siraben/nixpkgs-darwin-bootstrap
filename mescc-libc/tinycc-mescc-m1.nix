args:
with args;
runCommand "darwin-minimal-bootstrap-phase19-tinycc-mescc-m1-probe-amd64" { } ''
  mkdir -p $out/share/darwin-bootstrap

  mesLoadPath=${phase13-mes-source}/module:${phase13-mes-source}/mes/module:${mesNyacc}/share/nyacc-${nyaccVersion}/module
  MES_PREFIX=${phase13-mes-source} \
    GUILE_LOAD_PATH="$mesLoadPath" \
    MES_STACK=6000000 \
    MES_ARENA=60000000 \
    MES_MAX_ARENA=60000000 \
    srcdest=${phase13-mes-source}/ \
    includedir=${phase13-mes-source}/include \
    libdir=${phase13-mes-source}/lib \
    M1=${phase9-m1}/bin/M1 \
    HEX2=${phase10-hex2}/bin/hex2 \
    ${phase16-mes-m2}/bin/mes-m2 --no-auto-compile -e main ${phase16-mes-m2}/bin/mescc.scm -- \
      -S \
      -o tcc.M1 \
      -I ${tinyccMesSrc} \
      -I ${tinyccMesSrc}/include \
      -I ${phase13-mes-source}/include \
      -D BOOTSTRAP=1 \
      -D HAVE_LONG_LONG=1 \
      -D TCC_TARGET_X86_64=1 \
      -D inline= \
      -D CONFIG_TCCDIR=\"\" \
      -D CONFIG_SYSROOT=\"\" \
      -D CONFIG_TCC_CRTPREFIX=\"{B}\" \
      -D CONFIG_TCC_ELFINTERP=\"/mes/loader\" \
      -D CONFIG_TCC_LIBPATHS=\"{B}\" \
      -D CONFIG_TCC_SYSINCLUDEPATHS=\"${tinyccMesSrc}/include:${phase13-mes-source}/include\" \
      -D TCC_LIBGCC=\"libc.a\" \
      -D TCC_LIBTCC1=\"libtcc1.a\" \
      -D CONFIG_TCC_LIBTCC1_MES=0 \
      -D CONFIG_TCCBOOT=1 \
      -D CONFIG_TCC_STATIC=1 \
      -D CONFIG_USE_LIBGCC=1 \
      -D TCC_MES_LIBC=1 \
      -D TCC_VERSION=\"0.9.28-darwin-bootstrap\" \
      -D ONE_SOURCE=1 \
      ${tinyccMesSrc}/tcc.c \
    > tcc-mescc.stdout 2> tcc-mescc.stderr

  test -s tcc.M1
  sed -i.bak '/^<$/d' tcc.M1
  rm -f tcc.M1.bak
  grep -q '^:main' tcc.M1

  cp tcc.M1 tcc-mescc.stdout tcc-mescc.stderr \
    $out/share/darwin-bootstrap/
''
