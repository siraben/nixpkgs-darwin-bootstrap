args:
with args;
##
## WIP — task #12 first attempt.
##
## Goal: build GMP as a standalone Nix derivation using a bootstrap-chain
## compiler so phase45/46/47 can consume it via --with-gmp instead of
## extracting it in-tree, matching nixpkgs minimal-bootstrap structure.
##
## Status: BLOCKED. Both phase44 (gcc46-cxx) and phase45 (gcc10) fail to
## build external GMP:
##
##  - phase44: ld: library not found for -lgcc_ext.10.5
##             (gcc 4.6 Darwin specs reference legacy compat lib we don't ship)
##  - phase45: stddef.h:27: unterminated #if  /
##             limits.h:34: syslimits.h: No such file or directory
##             (phase45's compiler-only handoff bundles incomplete headers
##             that work for the chain's internal compiles but not for
##             external configure tests)
##
## The blocker is the same compiler-only handoff issue documented in
## task #13: our bootstrap GCCs are frontends-without-complete-runtimes,
## so they can't build external software. Resolving #13 (phase46 ships
## its own libgcc + libstdc++ + complete headers) unblocks #12.
##
## This file is kept in-tree as the foundation: once #13 lands, swap
## `compiler` below to the resulting full-closure GCC and the phase
## should build end-to-end.
##
    if hostPlatform.isx86_64 then
      let
        version = gccLatestGmpVersion;
        tarball = gccLatestGmpTarball;
      in
      runCommand "darwin-minimal-bootstrap-phase26c-gmp-${version}-amd64" {
        nativeBuildInputs = [ perl ];
      } ''
        mkdir -p work $out/share/darwin-bootstrap
        cd work
        tar -xf ${tarball}
        cd gmp-${version}

        ## Use phase46 GCC 15.2 as the bootstrap compiler. Earlier candidates:
        ##   - phase44 (gcc46-cxx): missing libgcc_ext.10.5
        ##   - phase45 (gcc10): incomplete bundled stddef.h / missing syslimits.h
        ## Phase46 ships a more complete bootstrap-sysroot at
        ## $out/x86_64-apple-darwin/include/ (stdio.h, limits.h, etc.) which
        ## external configure tests can resolve.  Apple SDK still needed for
        ## libSystem at link time; see todos #11/#13.
        compiler=${phase46-gcc-latest-bootstrap}
        sdk=${apple-sdk}/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk

        ## Match the configuration that gnu-hello.nix uses successfully —
        ## phase46 wrapper internally injects -isysroot / -Wl,-syslibroot
        ## when GCC_MODERN_WRAPPER_HOST_SHORTCUTS=0.
        export PATH="$compiler/bin:${cctools}/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        export CC="$compiler/bin/gcc"
        export CXX="$compiler/bin/g++"
        export AR=${cctools}/bin/ar
        export RANLIB=${cctools}/bin/ranlib
        export NM=${cctools}/bin/nm
        export GCC_MODERN_WRAPPER_HOST_SHORTCUTS=0
        export GCC_MODERN_CONFTEST_TIMEOUT=120
        ## GMP 6.3.0's autoconf still ships configure tests written in K&R /
        ## pre-C99 style that GCC 15 rejects (mismatched function arity,
        ## implicit int return, etc.). Force -std=gnu89 + relax the strict
        ## diagnostics so configure can complete; GMP source itself is
        ## strictly typed and compiles cleanly under these flags.
        ## Use gnu99 (declarations in for-init are needed by gen-sieve.c);
        ## the warning relaxations are still needed for configure conftests.
        export CFLAGS="-O2 -g0 -std=gnu99 -Wno-implicit-function-declaration -Wno-implicit-int -Wno-int-conversion -Wno-incompatible-pointer-types -Wno-return-type"
        export CXXFLAGS="-O2 -g0"
        export MACOSX_DEPLOYMENT_TARGET=10.8

        ## --disable-assembly avoids the GMP asm fragments which depend on
        ## platform-specific assembler quirks; we lose some perf but the
        ## resulting libgmp.a is portable enough for GCC's purposes.
        ./configure \
          --prefix=$out \
          --build=x86_64-apple-darwin \
          --host=x86_64-apple-darwin \
          --enable-static \
          --disable-shared \
          --disable-assembly \
          --with-pic \
          > $out/share/darwin-bootstrap/configure.stdout \
          2> $out/share/darwin-bootstrap/configure.stderr

        ${phase39-gnumake}/bin/make -j"''${NIX_BUILD_CORES:-1}" \
          > $out/share/darwin-bootstrap/make.stdout \
          2> $out/share/darwin-bootstrap/make.stderr

        ${phase39-gnumake}/bin/make install \
          > $out/share/darwin-bootstrap/install.stdout \
          2> $out/share/darwin-bootstrap/install.stderr

        test -f $out/include/gmp.h
        test -f $out/lib/libgmp.a

        ## Smoke: compile and link a trivial GMP user
        cd $TMPDIR
        cat > smoke.c <<'C'
        #include <gmp.h>
        int main(void) {
          mpz_t a;
          mpz_init(a);
          mpz_set_ui(a, 42);
          unsigned long v = mpz_get_ui(a);
          mpz_clear(a);
          return v == 42 ? 0 : 1;
        }
        C
        "$compiler/bin/gcc" -isysroot $sdk -I $out/include smoke.c \
          $out/lib/libgmp.a -Wl,-syslibroot,$sdk -lSystem -o smoke
        ./smoke
        echo "phase26c bootstrap GMP smoke: ok" > $out/share/darwin-bootstrap/smoke.stdout
      ''
    else
      null
