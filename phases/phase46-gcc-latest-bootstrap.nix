args:
with args;
    if hostPlatform.isx86_64 then
      runCommand "darwin-minimal-bootstrap-phase46-gcc-${gccLatestVersion}-amd64" {
        nativeBuildInputs = [ perl ];
      } ''
        export GCC_MODERN_SDK_PATH=/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk
        ## phase46 keeps in-tree gmp/mpfr/mpc/isl: it's the compiler used
        ## to build phase26c-f, so we can't reference them here without a
        ## cycle. phase47 strict consumes external libs (the goal lands
        ## there). See todos task #12.
        export GCC_MODERN_HOST_CC=${stdenv.cc.cc}/bin/clang
        export GCC_MODERN_HOST_CXX=${stdenv.cc.cc}/bin/clang++
        export GCC_MODERN_LD=${darwin.binutils-unwrapped}/bin/ld
        export GCC_MODERN_AS=${darwin.binutils-unwrapped}/bin/as
        export SDKROOT=$GCC_MODERN_SDK_PATH
        export GCC_MODERN_TARGETS=all-gcc
        export GCC_MODERN_COMPILER_ONLY=1
        ## Task #13 first iteration: phase46 *can* build its own libgcc +
        ## libstdc++ (set GCC_MODERN_BUILD_TARGET_LIBS=1), and the resulting
        ## $out/include/c++/15.2.0 + lib/gcc/.../libgcc.a + lib/libstdc++.a
        ## packages cleanly. BUT phase47 strict's GCC 15.2 self-build then
        ## breaks at `cfn-operators.pd:192: error: no such operator
        ## 'BUILT_IN_CBR'` — when phase47's wrapper picks up phase46's
        ## matching libstdc++ instead of SDK libc++, the build-machine
        ## genmatch produces a cfn-operators.pd that match.pd doesn't
        ## understand (float128-related). Need to either disable libstdc++
        ## use in phase47's wrapper for the build-machine genmatch path
        ## or fix the float128 mismatch. Until that's resolved, phase46
        ## stays compiler-only.
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
