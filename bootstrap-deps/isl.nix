{
  runCommand,
  perl,
  apple-sdk,
  cctools,
  gnumake,
  bootstrap-gnumake,
  gccModernIslVersion,
  gccModernIslTarball,
  bootstrap-gmp,
  gcc-latest,
  ...
}:
let
  version = gccModernIslVersion;
  tarball = gccModernIslTarball;
in
runCommand "phase26f-isl-${version}" {
  nativeBuildInputs = [ perl ];
} ''
  mkdir -p work $out/share/darwin-bootstrap
  cd work
  tar -xf ${tarball}
  cd isl-${version}

  compiler=${gcc-latest}
  gmp=${bootstrap-gmp}
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

  ## Build only the library. GCC needs just libisl.a + the isl/*.h headers;
  ## `make all` additionally builds isl_test_cpp, a C++ TEST program that does
  ## not compile against the from-stage0 gcc-15's bootstrap libstdc++ (its
  ## <type_traits> is incomplete: std::is_nothrow_assignable<...>::value is
  ## undeclared). The test is irrelevant to the bootstrap, so build the library
  ## target and install only the library + headers + pkg-config data.
  ##
  ## gitversion.h is a BUILT_SOURCES header (isl_version.c #includes it) that
  ## `make all` generates first but the bare `libisl.la` target does not, so
  ## generate it explicitly before the library (a separate, serial make call to
  ## avoid a -j race against isl_version.lo).
  ${bootstrap-gnumake}/bin/make gitversion.h \
    > $out/share/darwin-bootstrap/make.stdout \
    2> $out/share/darwin-bootstrap/make.stderr

  ${bootstrap-gnumake}/bin/make libisl.la -j"''${NIX_BUILD_CORES:-1}" \
    >> $out/share/darwin-bootstrap/make.stdout \
    2>> $out/share/darwin-bootstrap/make.stderr

  ${bootstrap-gnumake}/bin/make \
    install-libLTLIBRARIES \
    install-nodist_pkgincludeHEADERS \
    install-pkgincludeHEADERS \
    install-pkgconfigDATA \
    > $out/share/darwin-bootstrap/install.stdout \
    2> $out/share/darwin-bootstrap/install.stderr

  test -f $out/include/isl/version.h
  test -f $out/lib/libisl.a

  echo "phase26f bootstrap ISL: ok" > $out/share/darwin-bootstrap/smoke.stdout
''
