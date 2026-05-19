args:
with args;
    if hostPlatform.isx86_64 then
      runCommand "darwin-minimal-bootstrap-phase47-gcc-${gccLatestVersion}-strict-amd64" { } ''
        export GCC_MODERN_TARGETS=all-gcc
        export GCC_MODERN_COMPILER_ONLY=1
        export GCC_MODERN_WRAPPER_HOST_SHORTCUTS=0
        export GCC_MODERN_HOST_BUILD_CC=0
        ${root + "/scripts/gcc-modern/bootstrap-gcc.sh"} \
          ${phase43-gcc-latest-source} \
          ${phase46-gcc-latest-bootstrap} \
          ${phase39-gnumake} \
          ${phase46-gcc-latest-bootstrap} \
          ${cctools} \
          "$out" \
          ${gccLatestVersion} \
          gcc-latest
      ''
    else
      null
