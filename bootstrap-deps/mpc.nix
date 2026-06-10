{
  runCommand,
  perl,
  apple-sdk,
  cctools,
  gnumake,
  bootstrap-gnumake,
  gccModernMpcVersion,
  gccModernMpcTarball,
  bootstrap-gmp,
  bootstrap-mpfr,
  gcc-latest,
  root,
  ...
}:
let
  version = gccModernMpcVersion;
  tarball = gccModernMpcTarball;
in
runCommand "phase26e-mpc-${version}" {
  nativeBuildInputs = [ perl ];
} ''
  mkdir -p work $out/share/darwin-bootstrap
  cd work
  tar -xf ${tarball}
  cd mpc-${version}

  compiler=${gcc-latest}
  gmp=${bootstrap-gmp}
  mpfr=${bootstrap-mpfr}
  sdk=${apple-sdk}/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk

  export PATH="$compiler/bin:${cctools}/bin:/usr/bin:/bin:/usr/sbin:/sbin"
  export CC="$compiler/bin/gcc"
  export CXX="$compiler/bin/g++"
  export AR=${cctools}/bin/ar
  export RANLIB=${cctools}/bin/ranlib
  export NM=${cctools}/bin/nm
  export GCC_MODERN_WRAPPER_HOST_SHORTCUTS=0
  export GCC_MODERN_CONFTEST_TIMEOUT=120
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
    --with-mpfr=$mpfr \
    > $out/share/darwin-bootstrap/configure.stdout \
    2> $out/share/darwin-bootstrap/configure.stderr

  ${bootstrap-gnumake}/bin/make -j"''${NIX_BUILD_CORES:-1}" \
    > $out/share/darwin-bootstrap/make.stdout \
    2> $out/share/darwin-bootstrap/make.stderr

  ${bootstrap-gnumake}/bin/make install \
    > $out/share/darwin-bootstrap/install.stdout \
    2> $out/share/darwin-bootstrap/install.stderr

  test -f $out/include/mpc.h
  test -f $out/lib/libmpc.a

  cd $TMPDIR
  cp ${root + "/bootstrap-deps/fixtures/mpc-smoke.c"} smoke.c
  "$compiler/bin/gcc" -isysroot $sdk \
    -I $out/include -I $mpfr/include -I $gmp/include smoke.c \
    $out/lib/libmpc.a $mpfr/lib/libmpfr.a $gmp/lib/libgmp.a \
    -Wl,-syslibroot,$sdk -lSystem -o smoke
  ./smoke
  echo "phase26e bootstrap MPC smoke: ok" > $out/share/darwin-bootstrap/smoke.stdout
''
