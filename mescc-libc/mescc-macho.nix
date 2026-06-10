{
  darwin,
  lib,
  hex2,
  mes-source,
  mes-m2,
  mescc-macho-probe,
  m0,
  m1,
  runCommand,
  source,
  ...
}:
runCommand "phase17-mescc-macho-probe" { } ''
  mkdir -p $out/share/darwin-bootstrap

  sed '/^<$/d' ${mes-m2}/share/darwin-bootstrap/trivial.M1 > trivial.M1

  ${m1}/bin/M1 \
    --architecture amd64 \
    --little-endian \
    -f ${mes-source}/lib/m2/x86_64/x86_64_defs.M1 \
    -f ${mes-source}/lib/x86_64-mes/x86_64.M1 \
    -f ${mes-source}/lib/darwin/x86_64-mes-mescc/crt1.M1 \
    -f trivial.M1 \
    -o trivial.hex2

  ${hex2}/bin/hex2 \
    --architecture amd64 \
    --little-endian \
    --base-address 0x1000000 \
    -f ${m0}/share/darwin-bootstrap/MACHO-amd64-lowdata.hex2 \
    -f trivial.hex2 \
    -o trivial-mescc

  linkeditOffset="$((0x800000 + 0x2000000))"
  dd if=/dev/zero of=trivial-mescc bs=1 count=1 seek="$((linkeditOffset - 1))" conv=notrunc
  chmod +x trivial-mescc

  source ${darwin.signingUtils}
  sign trivial-mescc

  ./trivial-mescc > trivial.stdout 2> trivial.stderr
  test ! -s trivial.stdout
  test ! -s trivial.stderr

  cp trivial-mescc trivial.hex2 trivial.stdout trivial.stderr \
    $out/share/darwin-bootstrap/
''
