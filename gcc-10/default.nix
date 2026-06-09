{
  apple-sdk,
  cctools,
  darwin,
  gcc10Version,
  gnumake,
  perl,
  phase34-tinycc-darwin-cc,
  phase39-gnumake,
  phase42-gcc10-source,
  phase44-gcc46-cxx-bootstrap,
  root,
  runCommand,
  stdenv,
  ...
}:
runCommand "phase45-gcc-${gcc10Version}" {
  nativeBuildInputs = [ perl ];
} ''
  export GCC_MODERN_SDK_PATH=${apple-sdk}/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk
  ## phase45 keeps in-tree gmp/mpfr/mpc/isl: it's the compiler that
  ## *builds* the standalone phase26c-f, so we can't reference them
  ## here without a cycle. phase46/47 use external (next-stage gain).
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
  export BOOTSTRAP_MAKE=${phase39-gnumake}/bin/make
  ${root + "/scripts/gcc-modern/bootstrap-gcc.sh"} \
    ${phase42-gcc10-source} \
    ${phase44-gcc46-cxx-bootstrap} \
    ${phase39-gnumake} \
    ${phase34-tinycc-darwin-cc} \
    ${cctools} \
    "$out" \
    ${gcc10Version} \
    gcc10
''
