{
  cctools,
  gcc46Version,
  perl,
  tinycc-darwin-cc,
  gcc46-all-gcc,
  root,
  runCommand,
  ...
}:
runCommand "gcc-${gcc46Version}-libgcc" {
  nativeBuildInputs = [ perl ];
} ''
  ${root + "/scripts/gcc-4.6/libgcc.sh"} \
    ${gcc46-all-gcc} \
    ${tinycc-darwin-cc} \
    ${cctools} \
    ${perl}/bin/perl \
    ${root + "/scripts/gcc-4.6/libgcc.pl"} \
    ${root + "/scripts/gcc-4.6/bootstrap-as.c"} \
    "$out" \
    ${gcc46Version} \
    ${root + "/scripts/gcc-4.6/xgcc-wrapper.sh"}
''
