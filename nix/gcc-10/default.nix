{
  apple-sdk,
  cctools,
  darwin,
  gcc10Version,
  gnumake,
  perl,
  gnupatch,
  tinycc-darwin-cc,
  bootstrap-gnumake,
  gcc10-source,
  gcc46-cxx,
  root,
  runCommand,
  stdenv,
  ...
}:
runCommand "gcc-${gcc10Version}" {
  nativeBuildInputs = [ perl ];
} ''
  export GCC_MODERN_SDK_PATH=${apple-sdk}/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk
  export GCC_MODERN_PREPARED_SYSROOT=${root + "/bootstrap/headers/gcc-modern-sysroot"}
  export GCC_MODERN_SOURCE_PATCHES=${root + "/patches/gcc-modern"}
  export GNUPATCH=${gnupatch}/bin/patch
  ## gcc10 keeps in-tree gmp/mpfr/mpc/isl: it's the compiler that
  ## *builds* the standalone bootstrap-gmp/mpfr/mpc/isl, so we can't
  ## reference them here without a cycle. gcc-latest / gcc-latest-strict
  ## use the external libs.
  ## Build-helpers (genmatch/gengtype/build-libcpp) compile with the chain
  ## input compiler (gcc46-cxx) under GCC_MODERN_HOST_BUILD_CC=0 +
  ## GCC_MODERN_WRAPPER_HOST_SHORTCUTS=0 — the pure configuration
  ## gcc-latest-strict uses.  GCC 10 builds as C++98, which gcc-4.6 handles.  The
  ## HOST_CC/HOST_CXX exports remain for the wrapper guard paths, which
  ## refuse loudly if a shortcut is reached while the flags are 0.
  export GCC_MODERN_HOST_CC=${stdenv.cc}/bin/clang
  export GCC_MODERN_HOST_CXX=${stdenv.cc}/bin/clang++
  export GCC_MODERN_LD=${darwin.binutils-unwrapped}/bin/ld
  export GCC_MODERN_AS=${darwin.binutils-unwrapped}/bin/as
  export SDKROOT=$GCC_MODERN_SDK_PATH
  export GCC_MODERN_TARGETS=all-gcc
  export GCC_MODERN_COMPILER_ONLY=1
  export GCC_MODERN_WRAPPER_HOST_SHORTCUTS=0
  export GCC_MODERN_HOST_BUILD_CC=0
  ## gcc10 ships gcc-10's own libgcc + libstdc++ (include/c++/10.x with
  ## C++11 <type_traits>): gcc-latest's pure build-helpers (HOST_BUILD_CC=0)
  ## compile against these headers.  Mirrors gcc-latest's BUILD_TARGET_LIBS
  ## role for gcc-latest-strict.
  export GCC_MODERN_BUILD_TARGET_LIBS=1
  export BOOTSTRAP_MAKE=${bootstrap-gnumake}/bin/make
  ${root + "/scripts/gcc-modern/bootstrap-gcc.sh"} \
    ${gcc10-source} \
    ${gcc46-cxx} \
    ${bootstrap-gnumake} \
    ${tinycc-darwin-cc} \
    ${cctools} \
    "$out" \
    ${gcc10Version} \
    gcc10
''
