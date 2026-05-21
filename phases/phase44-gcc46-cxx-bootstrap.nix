args:
with args;
    if hostPlatform.isx86_64 then
      runCommand "darwin-minimal-bootstrap-phase44-gcc-${gcc46Version}-cxx-amd64" {
        nativeBuildInputs = [ perl ];
      } ''
        BOOTSTRAP_MAKE=${gnumake}/bin/make \
          GCC46_BOOTSTRAP_OBJECT_FORMAT=macho \
          BOOTSTRAP_JOBS=$NIX_BUILD_CORES \
          GCC46_BOOTSTRAP_HOST_CC_SOURCES=1 \
          GCC46_BOOTSTRAP_AS=/usr/bin/as \
          GCC46_BOOTSTRAP_LD=/usr/bin/ld \
          GCC46_BOOTSTRAP_MACHO_CC=/usr/bin/cc \
          GCC46_BOOTSTRAP_HOST_CC=/usr/bin/cc \
          PHASE44_SDK_PATH=/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk \
          PHASE44_REBUILD_MACHO_PREREQS=1 \
          ${root + "/scripts/gcc46/phase44-cxx.sh"} \
          ${phase35-gcc46-all-gcc} \
          ${phase37-gcc46-bootstrap} \
          ${phase39-gnumake} \
          ${phase34-tinycc-darwin-cc} \
          ${cctools} \
          "$out" \
          ${gcc46Version}
      ''
    else
      null
