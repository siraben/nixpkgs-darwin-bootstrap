{
  gcc46Version,
  elf64-to-m1,
  tinycc-darwin-cc,
  gcc46-all-gcc,
  gcc46-libgcc,
  root,
  runCommand,
  ...
}:
runCommand "gcc-${gcc46Version}-bootstrap" { } ''
  ${root + "/scripts/gcc46/phase37-driver.sh"} \
    ${gcc46-all-gcc} \
    ${gcc46-libgcc} \
    ${tinycc-darwin-cc} \
    ${root + "/scripts/gcc46/phase36-bootstrap-as.c"} \
    "" \
    ${elf64-to-m1}/bin/elf64-to-m1 \
    "$out" \
    ${gcc46Version}
''
