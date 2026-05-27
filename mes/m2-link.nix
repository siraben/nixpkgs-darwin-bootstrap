{
  darwin,
  lib,
  phase10-hex2,
  phase13-mes-source,
  phase14-mes-m2-probe,
  phase15-mes-macho-link-probe,
  phase26g-macho-patcher,
  phase3-m0,
  phase9-m1,
  runCommand,
  source,
  ...
}:
runCommand "phase15-mes-macho-link-probe" { } ''
  mkdir -p $out/share/darwin-bootstrap

  ${phase9-m1}/bin/M1 \
    --architecture amd64 \
    --little-endian \
    -f ${phase13-mes-source}/lib/m2/x86_64/x86_64_defs.M1 \
    -f ${phase13-mes-source}/lib/x86_64-mes/x86_64.M1 \
    -f ${phase13-mes-source}/lib/darwin/x86_64-mes-m2/crt1.M1 \
    -f ${phase14-mes-m2-probe}/share/darwin-bootstrap/mes.M1 \
    -o mes.hex2

  ${phase10-hex2}/bin/hex2 \
    --architecture amd64 \
    --little-endian \
    --base-address 0x1000000 \
    -f ${phase3-m0}/share/darwin-bootstrap/MACHO-amd64-lowdata.hex2 \
    -f mes.hex2 \
    -o mes-m2

  ${phase26g-macho-patcher}/bin/macho-patcher m2-segments mes.hex2 mes-m2

  linkeditOffset="$((0x800000 + 0x2000000))"
  dd if=/dev/zero of=mes-m2 bs=1 count=1 seek="$((linkeditOffset - 1))" conv=notrunc
  chmod +x mes-m2

  source ${darwin.signingUtils}
  sign mes-m2

  set +e
  MES_PREFIX=${phase13-mes-source} \
    GUILE_LOAD_PATH=${phase13-mes-source}/module:${phase13-mes-source}/mes/module \
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
