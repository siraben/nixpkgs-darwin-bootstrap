{
  apple-sdk,
  cctools,
  darwin,
  gccLatestVersion,
  lib,
  perl,
  tinycc-darwin-cc,
  bootstrap-gnumake,
  gcc-latest-source,
  gcc10,
  root,
  runCommand,
  stdenv,
  ...
}:
runCommand "gcc-${gccLatestVersion}" {
  nativeBuildInputs = [ perl ];
} ''
  export GCC_MODERN_SDK_PATH=${apple-sdk}/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk
  export GCC_MODERN_PREPARED_SYSROOT=${root + "/bootstrap/headers/gcc-modern-sysroot"}
  ## phase46 keeps in-tree gmp/mpfr/mpc/isl: it's the compiler used
  ## to build phase26c-f, so we can't reference them here without a
  ## cycle. phase47 strict consumes external libs (the goal lands
  ## there). See todos task #12.
  ## Build-helpers (genmatch/gengtype/build-libcpp) compile with the chain
  ## input compiler (phase45 gcc-10 + its from-stage0 libstdc++) under
  ## GCC_MODERN_HOST_BUILD_CC=0 + GCC_MODERN_WRAPPER_HOST_SHORTCUTS=0 — the
  ## pure configuration phase47 strict uses.  WRAPPER_HOST_SHORTCUTS=0 also
  ## cascades INPUT_HOST_SHORTCUTS and INPUT_HOST_LINK_SHORTCUTS to 0, so
  ## cc1/cc1plus link through the chain g++ wrapper.  The HOST_CC/HOST_CXX
  ## exports remain for the wrapper guard paths, which refuse loudly if a
  ## shortcut is reached while the flags are 0.
  export GCC_MODERN_HOST_CC=${stdenv.cc}/bin/clang
  export GCC_MODERN_HOST_CXX=${stdenv.cc}/bin/clang++
  export GCC_MODERN_LD=${darwin.binutils-unwrapped}/bin/ld
  export GCC_MODERN_AS=${darwin.binutils-unwrapped}/bin/as
  export SDKROOT=$GCC_MODERN_SDK_PATH
  export GCC_MODERN_TARGETS=all-gcc
  export GCC_MODERN_COMPILER_ONLY=1
  export GCC_MODERN_WRAPPER_HOST_SHORTCUTS=0
  export GCC_MODERN_HOST_BUILD_CC=0
  ## pex-unix.c gates its posix_spawn path on the function probes, which
  ## link against libSystem and succeed even with ac_cv_header_spawn_h=no
  ## (the SDK spawn.h does not parse under the gcc-10 input compiler);
  ## both go off so pex uses fork/exec.
  export ac_cv_func_posix_spawn=no
  export ac_cv_func_posix_spawnp=no
  ## Task #13/#67: phase46 builds its own libgcc + libstdc++ so the
  ## resulting $out/include/c++/15.2.0 (with C++11 <type_traits>) is what
  ## phase47's pure-from-stage0 build-helpers compile against. Without this
  ## phase46 ships only the inherited gcc-4.6 headers (include/c++/4.6.4),
  ## which lack std::is_trivially_destructible, so phase47 (HOST_BUILD_CC=0,
  ## no host clang) cannot compile gcc-15's own vec.h build-helpers.
  ## Known downstream follow-up: phase47 may then hit cfn-operators.pd
  ## 'BUILT_IN_CBR' (a float128/genmatch mismatch) — fixed separately.
  export GCC_MODERN_BUILD_TARGET_LIBS=1
  export BOOTSTRAP_MAKE=${bootstrap-gnumake}/bin/make
  ${root + "/scripts/gcc-modern/bootstrap-gcc.sh"} \
    ${gcc-latest-source} \
    ${gcc10} \
    ${bootstrap-gnumake} \
    ${tinycc-darwin-cc} \
    ${cctools} \
    "$out" \
    ${gccLatestVersion} \
    gcc-latest
''
