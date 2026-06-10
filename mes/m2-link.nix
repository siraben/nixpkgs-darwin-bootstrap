{
  darwin,
  lib,
  hex2,
  mes-source,
  mes-m2-probe,
  mes-macho-link-probe,
  macho-patcher,
  m0,
  m1,
  runCommand,
  source,
  ...
}:
runCommand "phase15-mes-macho-link-probe" { } ''
  mkdir -p $out/share/darwin-bootstrap

  ${m1}/bin/M1 \
    --architecture amd64 \
    --little-endian \
    -f ${mes-source}/lib/m2/x86_64/x86_64_defs.M1 \
    -f ${mes-source}/lib/x86_64-mes/x86_64.M1 \
    -f ${mes-source}/lib/darwin/x86_64-mes-m2/crt1.M1 \
    -f ${mes-m2-probe}/share/darwin-bootstrap/mes.M1 \
    -o mes.hex2

  ${hex2}/bin/hex2 \
    --architecture amd64 \
    --little-endian \
    --base-address 0x1000000 \
    -f ${m0}/share/darwin-bootstrap/MACHO-amd64-lowdata.hex2 \
    -f mes.hex2 \
    -o mes-m2

  ${macho-patcher}/bin/macho-patcher m2-segments mes.hex2 mes-m2

  linkeditOffset="$((0x800000 + 0x2000000))"
  dd if=/dev/zero of=mes-m2 bs=1 count=1 seek="$((linkeditOffset - 1))" conv=notrunc
  chmod +x mes-m2

  source ${darwin.signingUtils}
  sign mes-m2

  set +e
  MES_PREFIX=${mes-source} \
    GUILE_LOAD_PATH=${mes-source}/module:${mes-source}/mes/module \
    ./mes-m2 -c "(display 'Hello,M2-mes!) (newline)" \
    > mes-m2-run.stdout 2> mes-m2-run.stderr
  status="$?"
  set -e

  test "$status" -eq 0
  grep -q 'Hello,M2-mes!' mes-m2-run.stdout
  test ! -s mes-m2-run.stderr

  cp mes-m2 mes.hex2 mes-m2-run.stdout mes-m2-run.stderr \
    $out/share/darwin-bootstrap/
''
