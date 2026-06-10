{
  cctools,
  gcc_latest,
  gnuHelloTarball,
  gnuHelloVersion,
  gnumake,
  hostPlatform,
  bootstrap-gnumake,
  cctools-ar,
  gcc-latest,
  gcc-latest-strict,
  runCommand,
  ...
}:
let
  buildWithBootstrapGcc =
    name: compiler:
    if hostPlatform.isx86_64 then
      runCommand name { } ''
        tar -xf ${gnuHelloTarball}
        mkdir build
        cd build

        ## ar/ranlib are the chain-built cctools ar/ranlib (phase39b, gcc-15);
        ## prepend so the chain ar resolves first. ARFLAGS=rcS keeps ar from
        ## auto-exec'ing ranlib (Make runs $(RANLIB) separately); the chain ar
        ## is downstream of gcc-15 so it can't replace host ar in the gcc chain.
        export PATH="${cctools-ar}/bin:${compiler}/bin:${cctools}/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        export CC="${compiler}/bin/gcc"
        export CXX="${compiler}/bin/g++"
        export AR="${cctools-ar}/bin/ar"
        export RANLIB="${cctools-ar}/bin/ranlib"
        export GCC_MODERN_WRAPPER_HOST_SHORTCUTS=0
        export GCC_MODERN_CONFTEST_TIMEOUT=120
        export CFLAGS="-O2 -g0"
        export CXXFLAGS="-O2 -g0"

        ../hello-${gnuHelloVersion}/configure --disable-nls --prefix="$out" \
          > configure.stdout \
          2> configure.stderr
        ## chain-built make (phase39-gnumake, from tcc). It now builds GNU Hello's
        ## Automake recipe graph cleanly incl. parallel -j (the old segfault is
        ## gone with GNU Make 4.4.1).
        ${bootstrap-gnumake}/bin/make -j"''${NIX_BUILD_CORES:-1}" ARFLAGS=rcS \
          > make.stdout \
          2> make.stderr

        ./hello > hello.stdout
        ./hello --version > version.stdout
        ./hello --help > help.stdout
        grep -qx 'Hello, world!' hello.stdout
        grep -q 'GNU Hello' version.stdout
        grep -q 'Usage:' help.stdout

        mkdir -p "$out/bin" "$out/share/darwin-bootstrap"
        cp ./hello "$out/bin/hello"
        cp configure.stdout configure.stderr make.stdout make.stderr \
          hello.stdout version.stdout help.stdout \
          "$out/share/darwin-bootstrap/"
        shasum -a 256 "$out/bin/hello" | tee "$out/share/darwin-bootstrap/hello.sha256"
      ''
    else
      null;

  gnu-hello-gcc-latest-bootstrap =
    buildWithBootstrapGcc
      "darwin-minimal-bootstrap-gnu-hello-${gnuHelloVersion}-gcc-latest"
      gcc-latest;

  gnu-hello-gcc-latest-strict =
    buildWithBootstrapGcc
      "darwin-minimal-bootstrap-gnu-hello-${gnuHelloVersion}-gcc-latest-strict"
      gcc-latest-strict;

  gnu-hello-nixpkgs-gcc-latest =
    if hostPlatform.isx86_64 then
      runCommand "darwin-minimal-bootstrap-gnu-hello-${gnuHelloVersion}-nixpkgs-gcc-latest" {
        hardeningDisable = [ "fortify" ];
      } ''
        tar -xf ${gnuHelloTarball}
        mkdir build
        cd build

        export PATH="${gcc_latest}/bin:${gnumake}/bin:${cctools}/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        export CC="${gcc_latest}/bin/gcc"
        export CXX="${gcc_latest}/bin/g++"
        export NIX_HARDENING_ENABLE=
        export CFLAGS="-O2 -g0 -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=0"
        export CXXFLAGS="-O2 -g0 -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=0"

        ../hello-${gnuHelloVersion}/configure --disable-nls --prefix="$out" \
          > configure.stdout \
          2> configure.stderr
        ${gnumake}/bin/make -j"''${NIX_BUILD_CORES:-1}" ARFLAGS=rc \
          > make.stdout \
          2> make.stderr

        ./hello > hello.stdout
        ./hello --version > version.stdout
        ./hello --help > help.stdout
        grep -qx 'Hello, world!' hello.stdout
        grep -q 'GNU Hello' version.stdout
        grep -q 'Usage:' help.stdout

        mkdir -p "$out/bin" "$out/share/darwin-bootstrap"
        cp ./hello "$out/bin/hello"
        cp configure.stdout configure.stderr make.stdout make.stderr \
          hello.stdout version.stdout help.stdout \
          "$out/share/darwin-bootstrap/"
        {
          printf 'nixpkgs_gcc_latest_version='
          ${gcc_latest}/bin/gcc -dumpversion
        } > "$out/share/darwin-bootstrap/compiler.txt"
        shasum -a 256 "$out/bin/hello" | tee "$out/share/darwin-bootstrap/hello.sha256"
      ''
    else
      null;

  gnu-hello-hash-comparison =
    if hostPlatform.isx86_64 then
      runCommand "darwin-minimal-bootstrap-gnu-hello-hash-comparison" { } ''
        mkdir -p "$out/share/darwin-bootstrap"
        phase46_hash="$(cut -d' ' -f1 ${gnu-hello-gcc-latest-bootstrap}/share/darwin-bootstrap/hello.sha256)"
        phase47_hash="$(cut -d' ' -f1 ${gnu-hello-gcc-latest-strict}/share/darwin-bootstrap/hello.sha256)"
        nixpkgs_hash="$(cut -d' ' -f1 ${gnu-hello-nixpkgs-gcc-latest}/share/darwin-bootstrap/hello.sha256)"
        {
          printf 'phase46_gcc_latest=%s\n' "$phase46_hash"
          printf 'phase47_gcc_latest_strict=%s\n' "$phase47_hash"
          printf 'nixpkgs_gcc_latest=%s\n' "$nixpkgs_hash"
          printf 'phase46_phase47_equal=%s\n' "$([ "$phase46_hash" = "$phase47_hash" ] && echo yes || echo no)"
          printf 'phase47_nixpkgs_equal=%s\n' "$([ "$phase47_hash" = "$nixpkgs_hash" ] && echo yes || echo no)"
          cat ${gnu-hello-nixpkgs-gcc-latest}/share/darwin-bootstrap/compiler.txt
        } > "$out/share/darwin-bootstrap/hello-hashes.txt"
      ''
    else
      null;
in
{
  inherit
    gnu-hello-gcc-latest-bootstrap
    gnu-hello-gcc-latest-strict
    gnu-hello-nixpkgs-gcc-latest
    gnu-hello-hash-comparison
    ;
}
