{
  tinycc-self-object-probe,
  elf64-to-m1,
  tinycc-self-m1-probe,
  m1,
  runCommand,
  ...
}:
runCommand "phase28-tinycc-self-m1-probe" { } ''
  mkdir -p $out/share/darwin-bootstrap

  ${elf64-to-m1}/bin/elf64-to-m1 --prefix tcc_self_ \
    ${tinycc-self-object-probe}/share/darwin-bootstrap/tcc.o \
    tcc-from-elf.M1

  grep -q '^:main$' tcc-from-elf.M1
  grep -q '^:tcc_new$' tcc-from-elf.M1
  grep -q '^%memcpy$' tcc-from-elf.M1
  grep -q '^%vsnprintf$' tcc-from-elf.M1
  grep -q '^:ELF_data$' tcc-from-elf.M1

  ${m1}/bin/M1 \
    --architecture amd64 \
    --little-endian \
    -f tcc-from-elf.M1 \
    -o tcc-from-elf.hex2

  test -s tcc-from-elf.hex2

  cp tcc-from-elf.M1 tcc-from-elf.hex2 $out/share/darwin-bootstrap/
''
