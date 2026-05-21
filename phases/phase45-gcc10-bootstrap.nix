args:
with args;
    if hostPlatform.isx86_64 then
      runCommand "darwin-minimal-bootstrap-phase45-gcc-${gcc10Version}-amd64" {
        nativeBuildInputs = [ perl ];
      } ''
        export GCC_MODERN_SDK_PATH=/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk
        export GCC_MODERN_TARGETS=all-gcc
        export GCC_MODERN_COMPILER_ONLY=1
        export BOOTSTRAP_MAKE=${gnumake}/bin/make
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
    else
      null
