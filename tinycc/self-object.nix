args:
with args;
runCommand "darwin-minimal-bootstrap-phase25-tinycc-self-object-probe-amd64" { } ''
  mkdir -p $out/share/darwin-bootstrap include

  cp -R ${phase13-mes-source}/include/. include/
  chmod -R u+w include
  cp -R ${tinyccMesSrc}/include/. include/

  ${phase23-tinycc-mescc-link-probe}/bin/tcc -c \
    -I$PWD/include \
    -DBOOTSTRAP=1 \
    -DHAVE_LONG_LONG=1 \
    -DTCC_TARGET_X86_64=1 \
    -Dinline= \
    -D'CONFIG_TCCDIR=""' \
    -D'CONFIG_SYSROOT=""' \
    -D'CONFIG_TCC_CRTPREFIX="{B}"' \
    -D'CONFIG_TCC_ELFINTERP="/mes/loader"' \
    -D'CONFIG_TCC_LIBPATHS="{B}"' \
    -D'TCC_LIBGCC="libc.a"' \
    -D'TCC_LIBTCC1="libtcc1.a"' \
    -DCONFIG_TCC_LIBTCC1_MES=0 \
    -DCONFIG_TCCBOOT=1 \
    -DCONFIG_TCC_STATIC=1 \
    -DCONFIG_USE_LIBGCC=1 \
    -DTCC_MES_LIBC=1 \
    -D'TCC_VERSION="0.9.28-darwin-bootstrap"' \
    -DONE_SOURCE=1 \
    ${tinyccMesSrc}/tcc.c \
    -otcc.o \
    > tcc-self.stdout \
    2> tcc-self.stderr

  test "$(od -An -tx1 -N4 tcc.o | tr -d ' \n')" = "7f454c46"
  grep -q 'implicit declaration of function' tcc-self.stderr

  cp tcc.o tcc-self.stdout tcc-self.stderr $out/share/darwin-bootstrap/
''
