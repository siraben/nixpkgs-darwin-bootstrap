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

        ## Use phase45 GCC 10 as the bootstrap compiler. Phase44 (GCC 4.6)
        ## would be closer to nixpkgs minimal-bootstrap's gcc46-cxx → gmp
        ## ordering, but its Darwin specs reference libgcc_ext.10.5 which
        ## the chain doesn't ship; phase45's GCC 10 is the first modern
        ## frontend with usable Darwin codegen for external builds.
        ## Apple SDK still needed for libSystem; see todos #11/#13.
        compiler=${phase45-gcc10-bootstrap}
        sdk=/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk

        export PATH="$compiler/bin:${cctools}/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        export CC="$compiler/bin/gcc"
        export CXX="$compiler/bin/g++"
        export AR=${cctools}/bin/ar
        export RANLIB=${cctools}/bin/ranlib
        export NM=${cctools}/bin/nm
        export CFLAGS="-O2 -g0 -isysroot $sdk"
        export CXXFLAGS="-O2 -g0 -isysroot $sdk"
        export LDFLAGS="-Wl,-syslibroot,$sdk"
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

        ${gnumake}/bin/make -j"''${NIX_BUILD_CORES:-1}" \
          > $out/share/darwin-bootstrap/make.stdout \
          2> $out/share/darwin-bootstrap/make.stderr

        ${gnumake}/bin/make install \
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
