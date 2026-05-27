args:
with args;
runCommand "phase36-gcc-${gcc46Version}-libgcc" {
  nativeBuildInputs = [ perl ];
} ''
  ${root + "/scripts/gcc46/phase36-libgcc.sh"} \
    ${phase35-gcc46-all-gcc} \
    ${phase34-tinycc-darwin-cc} \
    ${cctools} \
    ${perl}/bin/perl \
    ${root + "/scripts/gcc46/phase36-libgcc.pl"} \
    ${root + "/scripts/gcc46/phase36-bootstrap-as.awk"} \
    "$out" \
    ${gcc46Version} \
    ${root + "/scripts/gcc46/phase36-xgcc-wrapper.sh"}
''
