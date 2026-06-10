## All GCC 4.6 sources are compiled by the chain compiler: phase35 cc1
## driven through the phase37 driver (GCC46_BOOTSTRAP_HOST_CC_SOURCES=0).
## Measured per-file cc1 cost is 30s-4min (combine.c 125s, insn-recog.c
## 243s); with PHASE44_MAIN_JOBS=$NIX_BUILD_CORES the build completes in
## a few hours.
##
## Remaining phase44 host-tool boundary (next hardening targets):
## GCC46_BOOTSTRAP_MACHO_CC (nixpkgs clang, drives linking only) and
## GCC46_BOOTSTRAP_AS/LD (nixpkgs binutils as/ld).  No host compiler
## touches any C source.
{
  apple-sdk,
  cctools,
  darwin,
  gcc46Version,
  perl,
  tinycc-darwin-cc,
  gcc46-all-gcc,
  gcc46,
  bootstrap-gnumake,
  root,
  runCommand,
  stdenv,
  ...
}:
runCommand "gcc-${gcc46Version}-cxx" {
  nativeBuildInputs = [ perl ];
} ''
  BOOTSTRAP_MAKE=${bootstrap-gnumake}/bin/make \
    GCC46_BOOTSTRAP_OBJECT_FORMAT=macho \
    BOOTSTRAP_JOBS=$NIX_BUILD_CORES \
    GCC46_BOOTSTRAP_HOST_CC_SOURCES=0 \
    GCC46_BOOTSTRAP_HOST_CC_GENERATED=0 \
    PHASE44_MAIN_JOBS=$NIX_BUILD_CORES \
    GCC46_BOOTSTRAP_AS=${darwin.binutils-unwrapped}/bin/as \
    GCC46_BOOTSTRAP_LD=${darwin.binutils-unwrapped}/bin/ld \
    GCC46_BOOTSTRAP_MACHO_CC=${stdenv.cc.cc}/bin/clang \
    PHASE44_SDK_PATH=${apple-sdk}/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk \
    PHASE44_REBUILD_MACHO_PREREQS=1 \
    ${root + "/scripts/gcc46/phase44-cxx.sh"} \
    ${gcc46-all-gcc} \
    ${gcc46} \
    ${bootstrap-gnumake} \
    ${tinycc-darwin-cc} \
    ${cctools} \
    "$out" \
    ${gcc46Version}
''
