args:
with args;
    if hostPlatform.isx86_64 then
      runCommand "darwin-minimal-bootstrap-phase46-gcc-${gccLatestVersion}-amd64" {
        nativeBuildInputs = [ perl ];
      } ''
        export GCC_MODERN_SDK_PATH=/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk
        export GCC_MODERN_HOST_CC=${stdenv.cc.cc}/bin/clang
        export GCC_MODERN_HOST_CXX=${stdenv.cc.cc}/bin/clang++
        export GCC_MODERN_LD=${darwin.binutils-unwrapped}/bin/ld
        export GCC_MODERN_AS=${darwin.binutils-unwrapped}/bin/as
        export SDKROOT=$GCC_MODERN_SDK_PATH
        export GCC_MODERN_TARGETS=all-gcc
        export GCC_MODERN_COMPILER_ONLY=1
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
    else
      null
