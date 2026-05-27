## Task #8 attempt 2026-05-23/24: setting GCC46_BOOTSTRAP_HOST_CC_SOURCES=0
## to have phase37/TCC compile GCC 4.6 source files (no nixpkgs clang
## shortcut). The compile is technically progressing — kept-failed dir
## showed active cc1 invocations cycling through .o files after libcpp /
## libdecnumber finished — but the total wall-clock is ~20+ hours for the
## ~250 GCC frontend translation units at multi-minute-per-file TCC speed.
## Codex's original session hit the same wall and never converged in
## finite time. Keeping HOST_CC_SOURCES=1 (nixpkgs clang, store-pinned
## via task #11) until phase37 is sped up or replaced. The split env
## GCC46_BOOTSTRAP_HOST_CC_GENERATED from commit 820dba7 stands ready for
## incremental shortcut reduction once the speed problem is solved.
args:
with args;
runCommand "phase44-gcc-${gcc46Version}-cxx" {
  nativeBuildInputs = [ perl ];
} ''
  BOOTSTRAP_MAKE=${gnumake}/bin/make \
    GCC46_BOOTSTRAP_OBJECT_FORMAT=macho \
    BOOTSTRAP_JOBS=$NIX_BUILD_CORES \
    GCC46_BOOTSTRAP_HOST_CC_SOURCES=1 \
    GCC46_BOOTSTRAP_AS=${darwin.binutils-unwrapped}/bin/as \
    GCC46_BOOTSTRAP_LD=${darwin.binutils-unwrapped}/bin/ld \
    GCC46_BOOTSTRAP_MACHO_CC=${stdenv.cc.cc}/bin/clang \
    GCC46_BOOTSTRAP_HOST_CC=${stdenv.cc.cc}/bin/clang \
    PHASE44_SDK_PATH=${apple-sdk}/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk \
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
