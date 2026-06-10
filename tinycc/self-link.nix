{
  darwin,
  hex2,
  hex2-data-relocs,
  tinycc-mescc-link-probe,
  elf64-to-m1,
  tinycc-self-m1-probe,
  m0,
  tinycc-self-link-candidate,
  m1,
  root,
  runCommand,
  source,
  ...
}:
runCommand "phase30-tinycc-self-link-candidate" { } ''
  mkdir -p $out/bin $out/share/darwin-bootstrap

  ${tinycc-mescc-link-probe}/bin/tcc -c \
    ${root + "/bootstrap/tinycc-sysv-libc.c"} \
    -o tinycc-sysv-libc.o \
    > tinycc-sysv-libc.stdout \
    2> tinycc-sysv-libc.stderr

  ${elf64-to-m1}/bin/elf64-to-m1 --prefix tinycc_sysv_libc_ \
    tinycc-sysv-libc.o \
    tinycc-sysv-libc.M1

  cp ${root + "/tinycc/fixtures/self-link-crt1-tcc-sysv.M1"} crt1-tcc-sysv.M1
  emit_code() {
    awk '
      /^:ELF_data$/ { data = 1; next }
      /^:HEX2_data$/ { next }
      data != 1 { print }
    ' "$1"
  }

  emit_data() {
    awk '
      /^:ELF_data$/ { data = 1; next }
      /^:HEX2_data$/ { next }
      data == 1 { print }
    ' "$1"
  }

  {
    cat crt1-tcc-sysv.M1
    cat ${root + "/bootstrap/tinycc-sysv-syscalls-amd64-darwin.M1"}
    emit_code ${tinycc-self-m1-probe}/share/darwin-bootstrap/tcc-from-elf.M1
    emit_code tinycc-sysv-libc.M1
    echo ':ELF_data'
    echo ':HEX2_data'
    emit_data ${tinycc-self-m1-probe}/share/darwin-bootstrap/tcc-from-elf.M1
    emit_data tinycc-sysv-libc.M1
  } > tcc-self-combined.M1

  ${m1}/bin/M1 \
    --architecture amd64 \
    --little-endian \
    -f tcc-self-combined.M1 \
    -o tcc-self.hex2

  ${hex2}/bin/hex2 \
    --architecture amd64 \
    --little-endian \
    --base-address 0x1000000 \
    -f ${m0}/share/darwin-bootstrap/MACHO-amd64-lowdata.hex2 \
    -f tcc-self.hex2 \
    -o tcc-self

  ${hex2-data-relocs}/bin/hex2-data-relocs patch tcc-self.hex2 tcc-self

  linkeditOffset="$((0x800000 + 0x2000000))"
  dd if=/dev/zero of=tcc-self bs=1 count=1 seek="$((linkeditOffset - 1))" conv=notrunc
  chmod +x tcc-self

  source ${darwin.signingUtils}
  sign tcc-self

  set +e
  ./tcc-self -version > tcc-self-version.stdout 2> tcc-self-version.stderr
  status="$?"
  set -e
  printf '%s\n' "$status" > tcc-self-version.status
  test "$status" = 0
  grep -q '0.9.28-darwin-bootstrap' tcc-self-version.stdout
  test ! -s tcc-self-version.stderr

  cp tcc-self $out/bin/tcc-self-candidate
  cp tinycc-sysv-libc.o tinycc-sysv-libc.M1 \
    tinycc-sysv-libc.stdout tinycc-sysv-libc.stderr \
    crt1-tcc-sysv.M1 tcc-self-combined.M1 tcc-self.hex2 \
    tcc-self-version.stdout tcc-self-version.stderr tcc-self-version.status \
    $out/share/darwin-bootstrap/
''
