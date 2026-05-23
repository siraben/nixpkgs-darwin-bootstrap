args:
with args;
    if hostPlatform.isx86_64 then
      let
        version = gccModernIslVersion;
        tarball = gccModernIslTarball;
      in
      runCommand "darwin-minimal-bootstrap-phase26f-isl-${version}-amd64" {
        nativeBuildInputs = [ perl ];
      } ''
        mkdir -p work $out/share/darwin-bootstrap
        cd work
        tar -xf ${tarball}
        cd isl-${version}

        compiler=${phase46-gcc-latest-bootstrap}
        gmp=${phase26c-bootstrap-gmp}
        sdk=/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk

        export PATH="$compiler/bin:${cctools}/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        export CC="$compiler/bin/gcc"
        export CXX="$compiler/bin/g++"
        export AR=${cctools}/bin/ar
        export RANLIB=${cctools}/bin/ranlib
        export NM=${cctools}/bin/nm
        export GCC_MODERN_WRAPPER_HOST_SHORTCUTS=0
        export GCC_MODERN_CONFTEST_TIMEOUT=120
        export CFLAGS="-O2 -g0 -std=gnu99 -Wno-implicit-function-declaration -Wno-implicit-int -Wno-int-conversion -Wno-incompatible-pointer-types -Wno-return-type"
        export CXXFLAGS="-O2 -g0 -std=gnu++14 -Wno-deprecated-declarations"
        export MACOSX_DEPLOYMENT_TARGET=10.8

        ./configure \
          --prefix=$out \
          --build=x86_64-apple-darwin \
          --host=x86_64-apple-darwin \
          --enable-static \
          --disable-shared \
          --with-gmp-prefix=$gmp \
          > $out/share/darwin-bootstrap/configure.stdout \
          2> $out/share/darwin-bootstrap/configure.stderr

        ${gnumake}/bin/make -j"''${NIX_BUILD_CORES:-1}" \
          > $out/share/darwin-bootstrap/make.stdout \
          2> $out/share/darwin-bootstrap/make.stderr

        ${gnumake}/bin/make install \
          > $out/share/darwin-bootstrap/install.stdout \
          2> $out/share/darwin-bootstrap/install.stderr

        test -f $out/include/isl/version.h
        test -f $out/lib/libisl.a

        echo "phase26f bootstrap ISL: ok" > $out/share/darwin-bootstrap/smoke.stdout
      ''
    else
      null
