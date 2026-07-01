{
  runCommand,
  perl,
  apple-sdk,
  cctools,
  gnumake,
  bootstrap-gnumake,
  gccLatestGmpVersion,
  gccLatestGmpTarball,
  gcc-latest,
  root,
  ...
}:
##
## Standalone GMP as a Nix derivation built by a bootstrap-chain compiler,
## matching the nixpkgs minimal-bootstrap structure.
##
## `gcc-latest` (the full-closure GCC that ships its own libgcc +
## libstdc++ + complete headers) compiles, installs, and smoke-tests GMP
## here; gcc-latest-strict consumes it via GCC_MODERN_EXTERNAL_GMP instead
## of extracting GMP in-tree. The earlier frontends-without-complete-
## runtimes GCCs (gcc46-cxx, gcc10) cannot build external software.
##
let
  version = gccLatestGmpVersion;
  tarball = gccLatestGmpTarball;
in
runCommand "gmp-${version}" {
  nativeBuildInputs = [ perl ];
} ''
  mkdir -p work $out/share/darwin-bootstrap
  cd work
  tar -xf ${tarball}
  cd gmp-${version}

  ## Use the gcc-latest GCC 15.2 as the bootstrap compiler. Earlier candidates:
  ##   - gcc46-cxx: missing libgcc_ext.10.5
  ##   - gcc10: incomplete bundled stddef.h / missing syslimits.h
  ## gcc-latest ships a more complete bootstrap-sysroot at
  ## $out/x86_64-apple-darwin/include/ (stdio.h, limits.h, etc.) which
  ## external configure tests can resolve.  Apple SDK still needed for
  ## libSystem at link time; see todos #11/#13.
  compiler=${gcc-latest}
  sdk=${apple-sdk}/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk

  ## Match the configuration that gnu-hello.nix uses successfully —
  ## the gcc-latest wrapper internally injects -isysroot / -Wl,-syslibroot
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

  ${bootstrap-gnumake}/bin/make -j"''${NIX_BUILD_CORES:-1}" \
    > $out/share/darwin-bootstrap/make.stdout \
    2> $out/share/darwin-bootstrap/make.stderr

  ${bootstrap-gnumake}/bin/make install \
    > $out/share/darwin-bootstrap/install.stdout \
    2> $out/share/darwin-bootstrap/install.stderr

  test -f $out/include/gmp.h
  test -f $out/lib/libgmp.a

  ## Smoke: compile and link a trivial GMP user
  cd $TMPDIR
  cp ${root + "/bootstrap-deps/fixtures/gmp-smoke.c"} smoke.c
  "$compiler/bin/gcc" -isysroot $sdk -I $out/include smoke.c \
    $out/lib/libgmp.a -Wl,-syslibroot,$sdk -lSystem -o smoke
  ./smoke
  echo "phase26c bootstrap GMP smoke: ok" > $out/share/darwin-bootstrap/smoke.stdout
''
