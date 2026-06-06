{
  apple-sdk,
  cctools,
  darwin,
  gccLatestVersion,
  gnumake,
  lib,
  perl,
  phase34-tinycc-darwin-cc,
  phase39-gnumake,
  phase43-gcc-latest-source,
  phase45-gcc10-bootstrap,
  root,
  runCommand,
  stdenv,
  ...
}:
runCommand "phase46-gcc-${gccLatestVersion}" {
  nativeBuildInputs = [ perl ];
} ''
  export GCC_MODERN_SDK_PATH=${apple-sdk}/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk
  ## phase46 keeps in-tree gmp/mpfr/mpc/isl: it's the compiler used
  ## to build phase26c-f, so we can't reference them here without a
  ## cycle. phase47 strict consumes external libs (the goal lands
  ## there). See todos task #12.
  ## Host build-helpers (genmatch/gengtype/build-libcpp) compile with the
  ## nixpkgs *wrapped* clang, not the bare ${stdenv.cc.cc} binary: the wrapper
  ## injects the SDK sysroot + libc++ include paths. The bare clang loses them
  ## once SDKROOT is store-pinned to ${apple-sdk} (whose MacOSX.sdk ships no
  ## libc++), so C++ build-helpers fail on '#include <new>'. These helpers only
  ## emit deterministic generated source, so the wrapper choice never reaches
  ## target codegen and the final compiler stays bit-identical.
  export GCC_MODERN_HOST_CC=${stdenv.cc}/bin/clang
  export GCC_MODERN_HOST_CXX=${stdenv.cc}/bin/clang++
  export GCC_MODERN_LD=${darwin.binutils-unwrapped}/bin/ld
  export GCC_MODERN_AS=${darwin.binutils-unwrapped}/bin/as
  export SDKROOT=$GCC_MODERN_SDK_PATH
  export GCC_MODERN_TARGETS=all-gcc
  export GCC_MODERN_COMPILER_ONLY=1
  ## Task #13/#67: phase46 builds its own libgcc + libstdc++ so the
  ## resulting $out/include/c++/15.2.0 (with C++11 <type_traits>) is what
  ## phase47's pure-from-stage0 build-helpers compile against. Without this
  ## phase46 ships only the inherited gcc-4.6 headers (include/c++/4.6.4),
  ## which lack std::is_trivially_destructible, so phase47 (HOST_BUILD_CC=0,
  ## no host clang) cannot compile gcc-15's own vec.h build-helpers.
  ## Known downstream follow-up: phase47 may then hit cfn-operators.pd
  ## 'BUILT_IN_CBR' (a float128/genmatch mismatch) — fixed separately.
  export GCC_MODERN_BUILD_TARGET_LIBS=1
  export BOOTSTRAP_MAKE=${gnumake}/bin/make
  ${root + "/scripts/gcc-modern/bootstrap-gcc.sh"} \
    ${phase43-gcc-latest-source} \
    ${phase45-gcc10-bootstrap} \
    ${phase39-gnumake} \
    ${phase34-tinycc-darwin-cc} \
    ${cctools} \
    "$out" \
    ${gccLatestVersion} \
    gcc-latest
''
