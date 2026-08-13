## GCC 4.6 C++ sources are compiled by the chain compiler: the gcc46-all-gcc
## cc1 driven through the gcc46 bootstrap driver (nix/scripts/gcc-4.6/driver.sh,
## GCC46_BOOTSTRAP_HOST_CC_SOURCES=0).  The C frontend cc1 is reused from the
## prior chain-built gcc46 stage instead of being rebuilt in this C++ packaging
## step.
## Measured per-file cc1 cost is 30s-4min (combine.c 125s, insn-recog.c
## 243s); with GCC46_CXX_MAIN_JOBS=$NIX_BUILD_CORES the build completes in
## a few hours.
## GCC46_CXX_REUSE_ALL_GCC_OBJECTS remains opt-in: gcc46-all-gcc's backend
## objects are TinyCC-built under a C-only configuration, so reusing them in
## this GCC-built C+C++ checkpoint needs stronger generated-header and output
## equivalence evidence before it can be the correctness-first default.
##
## Remaining gcc46-cxx host-tool boundary (next hardening targets):
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
  findutils,
  gnutar,
  gzip,
  gnupatch,
  root,
  runCommand,
  stdenv,
  ...
}:
runCommand "gcc-${gcc46Version}-cxx" {
  nativeBuildInputs = [ perl findutils gnutar gzip ];
  __impureHostDeps = [ "/usr/bin/codesign" ];
} ''
  GNUPATCH=${gnupatch}/bin/patch \
  GCC46_CXX_MPC_PATCH=${root + "/patches/gcc-4.6.4-mpc-assume-mpfr.patch"} \
  BOOTSTRAP_MAKE=${bootstrap-gnumake}/bin/make \
    GCC46_BOOTSTRAP_OBJECT_FORMAT=macho \
    BOOTSTRAP_JOBS=$NIX_BUILD_CORES \
    GCC46_BOOTSTRAP_HOST_CC_SOURCES=0 \
    GCC46_BOOTSTRAP_HOST_CC_GENERATED=0 \
    GCC46_CXX_MAIN_JOBS=$NIX_BUILD_CORES \
    GCC46_BOOTSTRAP_AS=${darwin.binutils-unwrapped}/bin/as \
    GCC46_BOOTSTRAP_LD=${darwin.binutils-unwrapped}/bin/ld \
    GCC46_BOOTSTRAP_MACHO_CC=${stdenv.cc.cc}/bin/clang \
    GCC46_CXX_SDK_PATH=${apple-sdk}/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk \
    GCC46_CXX_CSU_LIB=${darwin.Csu}/lib \
    GCC46_CXX_REBUILD_MACHO_PREREQS=1 \
    bash ${root + "/scripts/gcc-4.6/cxx.sh"} \
    ${gcc46-all-gcc} \
    ${gcc46} \
    ${bootstrap-gnumake} \
    ${tinycc-darwin-cc} \
    ${cctools} \
    "$out" \
    ${gcc46Version}
''
