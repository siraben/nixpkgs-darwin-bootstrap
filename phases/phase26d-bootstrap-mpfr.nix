args:
with args;
    if hostPlatform.isx86_64 then
      let
        version = gccModernMpfrVersion;
        tarball = gccModernMpfrTarball;
      in
      runCommand "darwin-minimal-bootstrap-phase26d-mpfr-${version}-amd64" {
        nativeBuildInputs = [ perl ];
      } ''
        mkdir -p work $out/share/darwin-bootstrap
        cd work
        tar -xf ${tarball}
        cd mpfr-${version}

        compiler=${phase46-gcc-latest-bootstrap}
        gmp=${phase26c-bootstrap-gmp}
        sdk=${apple-sdk}/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk

        export PATH="$compiler/bin:${cctools}/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        export CC="$compiler/bin/gcc"
        export CXX="$compiler/bin/g++"
        export AR=${cctools}/bin/ar
        export RANLIB=${cctools}/bin/ranlib
        export NM=${cctools}/bin/nm
        export GCC_MODERN_WRAPPER_HOST_SHORTCUTS=0
        export GCC_MODERN_CONFTEST_TIMEOUT=120
        ## Same GCC 15 / K&R-era configure-test relaxations as GMP.
        export CFLAGS="-O2 -g0 -std=gnu99 -Wno-implicit-function-declaration -Wno-implicit-int -Wno-int-conversion -Wno-incompatible-pointer-types -Wno-return-type"
        export CXXFLAGS="-O2 -g0"
        export MACOSX_DEPLOYMENT_TARGET=10.8

        ./configure \
          --prefix=$out \
          --build=x86_64-apple-darwin \
          --host=x86_64-apple-darwin \
          --enable-static \
          --disable-shared \
          --with-gmp=$gmp \
          > $out/share/darwin-bootstrap/configure.stdout \
          2> $out/share/darwin-bootstrap/configure.stderr

        ${phase39-gnumake}/bin/make -j"''${NIX_BUILD_CORES:-1}" \
          > $out/share/darwin-bootstrap/make.stdout \
          2> $out/share/darwin-bootstrap/make.stderr

        ${phase39-gnumake}/bin/make install \
          > $out/share/darwin-bootstrap/install.stdout \
          2> $out/share/darwin-bootstrap/install.stderr

        test -f $out/include/mpfr.h
        test -f $out/lib/libmpfr.a

        cd $TMPDIR
        cat > smoke.c <<'C'
        #include <mpfr.h>
        int main(void) {
          mpfr_t x;
          mpfr_init2(x, 53);
          mpfr_set_d(x, 1.5, MPFR_RNDN);
          double v = mpfr_get_d(x, MPFR_RNDN);
          mpfr_clear(x);
          return (v == 1.5) ? 0 : 1;
        }
        C
        "$compiler/bin/gcc" -isysroot $sdk -I $out/include -I $gmp/include smoke.c \
          $out/lib/libmpfr.a $gmp/lib/libgmp.a -Wl,-syslibroot,$sdk -lSystem -o smoke
        ./smoke
        echo "phase26d bootstrap MPFR smoke: ok" > $out/share/darwin-bootstrap/smoke.stdout
      ''
    else
      null
