{
  mes-source,
  runCommand,
  tinyccMesSrc,
  ...
}:
    {
      phase,
      boot,
      compiler,
    }:
runCommand "${phase}-tinycc-${boot}-object-probe" { } ''
  mkdir -p $out/share/darwin-bootstrap include

  cp -R ${mes-source}/include/. include/
  chmod -R u+w include
  cp -R ${tinyccMesSrc}/include/. include/

  ${compiler} -c \
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
    -o${boot}.o \
    > ${boot}.stdout \
    2> ${boot}.stderr

  test "$(od -An -tx1 -N4 ${boot}.o | tr -d ' \n')" = "7f454c46"
  test ! -s ${boot}.stdout

  cp ${boot}.o ${boot}.stdout ${boot}.stderr $out/share/darwin-bootstrap/
''
