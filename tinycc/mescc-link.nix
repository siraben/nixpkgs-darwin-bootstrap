{
  darwin,
  lib,
  hex2,
  mes-source,
  tinycc-mescc-m1-probe,
  mescc-libc-tcc-probe,
  tinycc-mescc-link-probe,
  macho-patcher,
  m0,
  m1,
  runCommand,
  source,
  ...
}:
runCommand "tinycc-mescc-link-probe" { } ''
  mkdir -p $out/bin $out/share/darwin-bootstrap

  split_m1() {
    input="$1"
    code="$2"
    data="$3"
    awk '
      /^:ELF_data$/ { data = 1; next }
      /^:HEX2_data$/ { next }
      data != 1 { print }
    ' "$input" > "$code"
    awk '
      /^:ELF_data$/ { data = 1; next }
      /^:HEX2_data$/ { next }
      data == 1 { print }
    ' "$input" > "$data"
  }

  split_m1 ${mescc-libc-tcc-probe}/share/darwin-bootstrap/libc+tcc.M1 libc-tcc.code.M1 libc-tcc.data.M1
  split_m1 ${tinycc-mescc-m1-probe}/share/darwin-bootstrap/tcc.M1 tcc.code.M1 tcc.data.M1

  {
    cat libc-tcc.code.M1
    cat tcc.code.M1
    echo ':ELF_data'
    echo ':HEX2_data'
    cat libc-tcc.data.M1
    cat tcc.data.M1
  } > tcc-combined.M1

  ${m1}/bin/M1 \
    --architecture amd64 \
    --little-endian \
    -f ${mes-source}/lib/m2/x86_64/x86_64_defs.M1 \
    -f ${mes-source}/lib/x86_64-mes/x86_64.M1 \
    -f ${mes-source}/lib/darwin/x86_64-mes-mescc/crt1-libc.M1 \
    -f tcc-combined.M1 \
    -o tcc.hex2

  ${hex2}/bin/hex2 \
    --architecture amd64 \
    --little-endian \
    --base-address 0x1000000 \
    -f ${m0}/share/darwin-bootstrap/MACHO-amd64-lowdata.hex2 \
    -f tcc.hex2 \
    -o tcc

  ${macho-patcher}/bin/macho-patcher m2-segments tcc.hex2 tcc

  linkeditOffset="$((0x800000 + 0x2000000))"
  dd if=/dev/zero of=tcc bs=1 count=1 seek="$((linkeditOffset - 1))" conv=notrunc
  chmod +x tcc

  source ${darwin.signingUtils}
  sign tcc

  ./tcc -version > tcc-version.stdout 2> tcc-version.stderr
  grep -q '0.9.28-darwin-bootstrap' tcc-version.stdout
  test ! -s tcc-version.stderr
  ./tcc --version > tcc-long-version.stdout 2> tcc-long-version.stderr
  grep -q '0.9.28-darwin-bootstrap' tcc-long-version.stdout
  test ! -s tcc-long-version.stderr

  cp tcc $out/bin/tcc
  cp tcc tcc.hex2 tcc-combined.M1 \
    tcc-version.stdout tcc-version.stderr \
    tcc-long-version.stdout tcc-long-version.stderr \
    $out/share/darwin-bootstrap/
''
