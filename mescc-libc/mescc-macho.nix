args:
with args;
runCommand "phase17-mescc-macho-probe" { } ''
  mkdir -p $out/share/darwin-bootstrap

  sed '/^<$/d' ${phase16-mes-m2}/share/darwin-bootstrap/trivial.M1 > trivial.M1

  ${phase9-m1}/bin/M1 \
    --architecture amd64 \
    --little-endian \
    -f ${phase13-mes-source}/lib/m2/x86_64/x86_64_defs.M1 \
    -f ${phase13-mes-source}/lib/x86_64-mes/x86_64.M1 \
    -f ${phase13-mes-source}/lib/darwin/x86_64-mes-mescc/crt1.M1 \
    -f trivial.M1 \
    -o trivial.hex2

  ${phase10-hex2}/bin/hex2 \
    --architecture amd64 \
    --little-endian \
    --base-address 0x1000000 \
    -f ${phase3-m0}/share/darwin-bootstrap/MACHO-amd64-lowdata.hex2 \
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
