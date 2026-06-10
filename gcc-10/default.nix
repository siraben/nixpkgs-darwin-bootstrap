{
  apple-sdk,
  cctools,
  darwin,
  gcc10Version,
  gnumake,
  perl,
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
  ## phase45 keeps in-tree gmp/mpfr/mpc/isl: it's the compiler that
  ## *builds* the standalone phase26c-f, so we can't reference them
  ## here without a cycle. phase46/47 use external (next-stage gain).
  ## Build-helpers (genmatch/gengtype/build-libcpp) compile with the chain
  ## input compiler (phase44 gcc-4.6) under GCC_MODERN_HOST_BUILD_CC=0 +
  ## GCC_MODERN_WRAPPER_HOST_SHORTCUTS=0 — the pure configuration the strict
  ## phase47 uses.  GCC 10 builds as C++98, which gcc-4.6 handles.  The
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
  ## phase45 ships gcc-10's own libgcc + libstdc++ (include/c++/10.x with
  ## C++11 <type_traits>): phase46's pure build-helpers (HOST_BUILD_CC=0)
  ## compile against these headers.  Mirrors phase46's BUILD_TARGET_LIBS
  ## role for phase47.
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
