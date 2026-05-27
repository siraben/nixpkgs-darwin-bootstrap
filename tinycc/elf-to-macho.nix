{
  darwin,
  phase10-hex2,
  phase23-tinycc-mescc-link-probe,
  phase26b-elf64-to-m1,
  phase26g-macho-patcher,
  phase27-tinycc-elf-to-macho-probe,
  phase3-m0,
  phase9-m1,
  runCommand,
  root,
  source,
  ...
}:
runCommand "phase27-tinycc-elf-to-macho-probe" { } ''
  mkdir -p $out/share/darwin-bootstrap

  cp ${root + "/tinycc/fixtures/elf-to-macho-hello.c"} hello.c
  ${phase23-tinycc-mescc-link-probe}/bin/tcc -c hello.c -o hello.o \
    > hello-c.stdout \
    2> hello-c.stderr
  test ! -s hello-c.stdout
  test ! -s hello-c.stderr
  test "$(od -An -tx1 -N4 hello.o | tr -d ' \n')" = "7f454c46"

  ${phase26b-elf64-to-m1}/bin/elf64-to-m1 --prefix hello_ hello.o hello-object.M1

  cp ${root + "/tinycc/fixtures/elf-to-macho-crt1-tcc-sysv.M1"} crt1-tcc-sysv.M1
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

  ${phase9-m1}/bin/M1 \
    --architecture amd64 \
    --little-endian \
    -f hello-combined.M1 \
    -o hello.hex2

  ${phase10-hex2}/bin/hex2 \
    --architecture amd64 \
    --little-endian \
    --base-address 0x1000000 \
    -f ${phase3-m0}/share/darwin-bootstrap/MACHO-amd64-lowdata.hex2 \
    -f hello.hex2 \
    -o hello

  ${phase26g-macho-patcher}/bin/macho-patcher m2-segments hello.hex2 hello

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
