{
  darwin,
  hex2,
  hex2-data-relocs,
  elf64-to-m1,
  m0,
  tinycc-self-link-candidate,
  tinycc-self-compile-probe,
  m1,
  runCommand,
  root,
  source,
  ...
}:
runCommand "phase31-tinycc-self-compile-probe" { } ''
  mkdir -p $out/share/darwin-bootstrap

  cp ${root + "/tinycc/fixtures/self-compile-hello.c"} hello.c
  ${tinycc-self-link-candidate}/bin/tcc-self-candidate \
    -c hello.c -o hello.o \
    > hello-c.stdout \
    2> hello-c.stderr

  test ! -s hello-c.stdout
  test ! -s hello-c.stderr
  test "$(od -An -tx1 -N4 hello.o | tr -d ' \n')" = "7f454c46"

  ${elf64-to-m1}/bin/elf64-to-m1 --prefix hello_ hello.o hello-object.M1

  cp ${root + "/tinycc/fixtures/self-compile-crt1-tcc-sysv.M1"} crt1-tcc-sysv.M1
  {
    cat crt1-tcc-sysv.M1
    awk '
      /^:ELF_data$/ { data = 1; next }
      /^:HEX2_data$/ { next }
      data != 1 { print }
    ' hello-object.M1
    echo ':ELF_data'
    echo ':HEX2_data'
    awk '
      /^:ELF_data$/ { data = 1; next }
      /^:HEX2_data$/ { next }
      data == 1 { print }
    ' hello-object.M1
  } > hello-combined.M1

  ${m1}/bin/M1 \
    --architecture amd64 \
    --little-endian \
    -f hello-combined.M1 \
    -o hello.hex2

  ${hex2}/bin/hex2 \
    --architecture amd64 \
    --little-endian \
    --base-address 0x1000000 \
    -f ${m0}/share/darwin-bootstrap/MACHO-amd64-lowdata.hex2 \
    -f hello.hex2 \
    -o hello

  ${hex2-data-relocs}/bin/hex2-data-relocs patch hello.hex2 hello

  linkeditOffset="$((0x800000 + 0x2000000))"
  dd if=/dev/zero of=hello bs=1 count=1 seek="$((linkeditOffset - 1))" conv=notrunc
  chmod +x hello

  source ${darwin.signingUtils}
  sign hello

  set +e
  ./hello
  status="$?"
  set -e
  test "$status" = 42

  cp hello.c hello.o hello-object.M1 crt1-tcc-sysv.M1 hello-combined.M1 hello.hex2 hello \
    hello-c.stdout hello-c.stderr \
    $out/share/darwin-bootstrap/
''
