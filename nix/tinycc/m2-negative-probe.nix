## Negative probe: confirm that M2-Planet (phase12) cannot compile
## tinycc's own source.  M2-Planet's parser predates ternary operators
## and the more recent C99 idioms tinycc uses, so this build is
## expected to fail with a specific parse error.  Pinning the failure
## message makes a silent regression in M2-Planet (or in our patch
## stack) loud — if upstream M2-Planet ever learns to parse the
## offending construct, this probe will fail-to-fail and we'll know
## the cycle-break around it can be revisited.
{
  hostPlatform,
  runCommand,
  m2-planet,
  stage0Sources,
  tinyccBootstrappableSrc,
  root,
  ...
}:
if hostPlatform.isx86_64 then
  runCommand "tinycc-m2-negative-probe" { } ''
    set +e
    ${m2-planet}/bin/M2-Planet \
      --architecture amd64 \
      -I ${tinyccBootstrappableSrc} \
      -I ${tinyccBootstrappableSrc}/include \
      -D float=int \
      -D double=long \
      -D BOOTSTRAP=1 \
      -D HAVE_LONG_LONG=1 \
      -D TCC_TARGET_X86_64=1 \
      -D LDOUBLE_SIZE=8 \
      -D CONFIG_TCCBOOT=1 \
      -D CONFIG_TCC_STATIC=1 \
      -D CONFIG_USE_LIBGCC=1 \
      -D TCC_MES_LIBC=1 \
      -D TCC_VERSION=\"0.9.28-bootstrap\" \
      -f ${stage0Sources}/M2libc/sys/types.h \
      -f ${stage0Sources}/M2libc/stddef.h \
      -f ${stage0Sources}/M2libc/stdint.h \
      -f ${stage0Sources}/M2libc/sys/utsname.h \
      -f ${root + "/M2libc/amd64/Darwin/unistd.c"} \
      -f ${root + "/M2libc/amd64/Darwin/fcntl.c"} \
      -f ${stage0Sources}/M2libc/fcntl.c \
      -f ${root + "/M2libc/amd64/Darwin/sys/stat.c"} \
      -f ${stage0Sources}/M2libc/ctype.c \
      -f ${stage0Sources}/M2libc/stdlib.c \
      -f ${stage0Sources}/M2libc/string.c \
      -f ${stage0Sources}/M2libc/stdarg.h \
      -f ${stage0Sources}/M2libc/stdio.h \
      -f ${stage0Sources}/M2libc/stdio.c \
      -f ${stage0Sources}/M2libc/bootstrappable.c \
      -f ${tinyccBootstrappableSrc}/elf.h \
      -f ${tinyccBootstrappableSrc}/libtcc.h \
      -f ${tinyccBootstrappableSrc}/tcc.h \
      -f ${tinyccBootstrappableSrc}/tccpp.c \
      -f ${tinyccBootstrappableSrc}/tccgen.c \
      -f ${tinyccBootstrappableSrc}/tccelf.c \
      -f ${tinyccBootstrappableSrc}/tccrun.c \
      -f ${tinyccBootstrappableSrc}/x86_64-gen.c \
      -f ${tinyccBootstrappableSrc}/x86_64-link.c \
      -f ${tinyccBootstrappableSrc}/i386-asm.c \
      -f ${tinyccBootstrappableSrc}/tccasm.c \
      -f ${tinyccBootstrappableSrc}/libtcc.c \
      -f ${tinyccBootstrappableSrc}/tcctools.c \
      -f ${tinyccBootstrappableSrc}/tcc.c \
      -o tcc.M1 > tcc-m2.stdout 2> tcc-m2.stderr
    status="$?"
    set -e

    test "$status" -ne 0
    grep -q "Invalid token '(' used in constant_expression_term" tcc-m2.stderr

    mkdir -p $out/share/darwin-bootstrap
    cp tcc-m2.stdout tcc-m2.stderr $out/share/darwin-bootstrap/
  ''
else
  null
