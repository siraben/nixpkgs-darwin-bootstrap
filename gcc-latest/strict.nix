{
  apple-sdk,
  cctools,
  darwin,
  gccLatestVersion,
  gnumake,
  perl,
  bootstrap-gmp,
  bootstrap-mpfr,
  bootstrap-mpc,
  bootstrap-isl,
  bootstrap-gnumake,
  gcc-latest-source,
  gcc-latest,
  root,
  runCommand,
  stdenv,
  ...
}:
runCommand "gcc-${gccLatestVersion}-strict" {
  nativeBuildInputs = [ perl ];
} ''
  export GCC_MODERN_SDK_PATH=${apple-sdk}/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk
  export GCC_MODERN_PREPARED_SYSROOT=${root + "/bootstrap/headers/gcc-modern-sysroot"}
  export GCC_MODERN_EXTERNAL_GMP=${bootstrap-gmp}
  export GCC_MODERN_EXTERNAL_MPFR=${bootstrap-mpfr}
  export GCC_MODERN_EXTERNAL_MPC=${bootstrap-mpc}
  export GCC_MODERN_EXTERNAL_ISL=${bootstrap-isl}
  export GCC_MODERN_HOST_CC=${stdenv.cc.cc}/bin/clang
  export GCC_MODERN_HOST_CXX=${stdenv.cc.cc}/bin/clang++
  export GCC_MODERN_LD=${darwin.binutils-unwrapped}/bin/ld
  export GCC_MODERN_AS=${darwin.binutils-unwrapped}/bin/as
  export SDKROOT=$GCC_MODERN_SDK_PATH
  export GCC_MODERN_TARGETS=all-gcc
  export GCC_MODERN_COMPILER_ONLY=1
  export GCC_MODERN_WRAPPER_HOST_SHORTCUTS=0
  export GCC_MODERN_HOST_BUILD_CC=0
  ## pex-unix.c gates its posix_spawn path on the function probes, which
  ## link against libSystem and succeed even with ac_cv_header_spawn_h=no
  ## (set in bootstrap-gcc.sh for gcc-latest); both go off so pex uses
  ## fork/exec.
  export ac_cv_func_posix_spawn=no
  export ac_cv_func_posix_spawnp=no
  export BOOTSTRAP_MAKE=${bootstrap-gnumake}/bin/make
  ${root + "/scripts/gcc-modern/bootstrap-gcc.sh"} \
    ${gcc-latest-source} \
    ${gcc-latest} \
    ${bootstrap-gnumake} \
    ${gcc-latest} \
    ${cctools} \
    "$out" \
    ${gccLatestVersion} \
    gcc-latest
''
