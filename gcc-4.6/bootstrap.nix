{
  gcc46Version,
  phase26b-elf64-to-m1,
  phase34-tinycc-darwin-cc,
  phase35-gcc46-all-gcc,
  phase36-gcc46-libgcc,
  root,
  runCommand,
  ...
}:
runCommand "phase37-gcc-${gcc46Version}-bootstrap" { } ''
  ${root + "/scripts/gcc46/phase37-driver.sh"} \
    ${phase35-gcc46-all-gcc} \
    ${phase36-gcc46-libgcc} \
    ${phase34-tinycc-darwin-cc} \
    ${root + "/scripts/gcc46/phase36-bootstrap-as.awk"} \
    "" \
    ${phase26b-elf64-to-m1}/bin/elf64-to-m1 \
    "$out" \
    ${gcc46Version}
''
