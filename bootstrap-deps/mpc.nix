args:
with args;
let
  version = gccModernMpcVersion;
  tarball = gccModernMpcTarball;
in
runCommand "darwin-minimal-bootstrap-phase26e-mpc-${version}-amd64" {
  nativeBuildInputs = [ perl ];
} ''
  mkdir -p work $out/share/darwin-bootstrap
  cd work
  tar -xf ${tarball}
  cd mpc-${version}

  compiler=${phase46-gcc-latest-bootstrap}
  gmp=${phase26c-bootstrap-gmp}
  mpfr=${phase26d-bootstrap-mpfr}
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

  ${gnumake}/bin/make -j"''${NIX_BUILD_CORES:-1}" \
    > $out/share/darwin-bootstrap/make.stdout \
    2> $out/share/darwin-bootstrap/make.stderr

  ${gnumake}/bin/make install \
    > $out/share/darwin-bootstrap/install.stdout \
    2> $out/share/darwin-bootstrap/install.stderr

  test -f $out/include/mpc.h
  test -f $out/lib/libmpc.a

  cd $TMPDIR
  cat > smoke.c <<'C'
  #include <mpc.h>
  int main(void) {
    mpc_t z;
    mpc_init2(z, 53);
    mpc_set_d_d(z, 1.0, 2.0, MPC_RNDNN);
    mpc_clear(z);
    return 0;
  }
  C
  "$compiler/bin/gcc" -isysroot $sdk \
    -I $out/include -I $mpfr/include -I $gmp/include smoke.c \
    $out/lib/libmpc.a $mpfr/lib/libmpfr.a $gmp/lib/libgmp.a \
    -Wl,-syslibroot,$sdk -lSystem -o smoke
  ./smoke
  echo "phase26e bootstrap MPC smoke: ok" > $out/share/darwin-bootstrap/smoke.stdout
''
