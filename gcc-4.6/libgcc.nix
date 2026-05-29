{
  cctools,
  gcc46Version,
  perl,
  phase34-tinycc-darwin-cc,
  phase35-gcc46-all-gcc,
  root,
  runCommand,
  ...
}:
runCommand "phase36-gcc-${gcc46Version}-libgcc" {
  nativeBuildInputs = [ perl ];
} ''
  ${root + "/scripts/gcc46/phase36-libgcc.sh"} \
    ${phase35-gcc46-all-gcc} \
    ${phase34-tinycc-darwin-cc} \
    ${cctools} \
    ${perl}/bin/perl \
    ${root + "/scripts/gcc46/phase36-libgcc.pl"} \
    ${root + "/scripts/gcc46/phase36-bootstrap-as.c"} \
    "$out" \
    ${gcc46Version} \
    ${root + "/scripts/gcc46/phase36-xgcc-wrapper.sh"}
''
