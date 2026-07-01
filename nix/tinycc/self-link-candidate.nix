{
  darwin,
  lib,
  hex2,
  hex2-data-relocs,
  elf64-to-m1,
  m0,
  m1,
  m1-split,
  root,
  runCommand,
  source,
  ...
}:
    {
      phase,
      boot,
      compiler,
      objectProbe,
    }:
runCommand "${phase}-tinycc-${boot}-link-candidate" { } ''
  mkdir -p $out/bin $out/share/darwin-bootstrap

  ${compiler} -c \
    ${root + "/bootstrap/tinycc-sysv-libc.c"} \
    -o tinycc-sysv-libc.o \
    > tinycc-sysv-libc.stdout \
    2> tinycc-sysv-libc.stderr

  ${elf64-to-m1}/bin/elf64-to-m1 --prefix tinycc_sysv_libc_ \
    tinycc-sysv-libc.o \
    tinycc-sysv-libc.M1

  ${elf64-to-m1}/bin/elf64-to-m1 --prefix ${lib.replaceStrings [ "-" ] [ "_" ] boot}_ \
    ${objectProbe}/share/darwin-bootstrap/${boot}.o \
    ${boot}.M1

  cp ${root + "/tinycc/fixtures/self-link-candidate-crt1-tcc-sysv.M1"} crt1-tcc-sysv.M1
  emit_code() {
    ${m1-split}/bin/m1-split --code < "$1"
  }

  emit_data() {
    ${m1-split}/bin/m1-split --data < "$1"
  }

  {
    cat crt1-tcc-sysv.M1
    cat ${root + "/bootstrap/tinycc-sysv-syscalls-amd64-darwin.M1"}
    emit_code ${boot}.M1
    emit_code tinycc-sysv-libc.M1
    echo ':ELF_data'
    echo ':HEX2_data'
    emit_data ${boot}.M1
    emit_data tinycc-sysv-libc.M1
  } > ${boot}-combined.M1

  ${m1}/bin/M1 \
    --architecture amd64 \
    --little-endian \
    -f ${boot}-combined.M1 \
    -o ${boot}.hex2

  ${hex2}/bin/hex2 \
    --architecture amd64 \
    --little-endian \
    --base-address 0x1000000 \
    -f ${m0}/share/darwin-bootstrap/MACHO-amd64-lowdata.hex2 \
    -f ${boot}.hex2 \
    -o ${boot}

  ${hex2-data-relocs}/bin/hex2-data-relocs patch ${boot}.hex2 ${boot}

  linkeditOffset="$((0x800000 + 0x2000000))"
  dd if=/dev/zero of=${boot} bs=1 count=1 seek="$((linkeditOffset - 1))" conv=notrunc
  chmod +x ${boot}

  source ${darwin.signingUtils}
  sign ${boot}

  ./${boot} -version > ${boot}-version.stdout 2> ${boot}-version.stderr
  printf '0\n' > ${boot}-version.status
  grep -q '0.9.28-darwin-bootstrap' ${boot}-version.stdout
  test ! -s ${boot}-version.stderr

  cp ${root + "/tinycc/fixtures/self-link-candidate-hello.c"} hello.c
  ./${boot} -c hello.c -o hello.o > hello-c.stdout 2> hello-c.stderr
  printf '0\n' > hello-c.status
  test "$(od -An -tx1 -N4 hello.o | tr -d ' \n')" = "7f454c46"

  cp ${boot} $out/bin/${boot}-candidate
  cp tinycc-sysv-libc.o tinycc-sysv-libc.M1 \
    tinycc-sysv-libc.stdout tinycc-sysv-libc.stderr \
    ${boot}.M1 crt1-tcc-sysv.M1 ${boot}-combined.M1 ${boot}.hex2 \
    ${boot}-version.stdout ${boot}-version.stderr ${boot}-version.status \
    hello.c hello.o hello-c.stdout hello-c.stderr hello-c.status \
    $out/share/darwin-bootstrap/
''
