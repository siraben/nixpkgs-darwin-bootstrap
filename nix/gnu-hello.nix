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

        ## ar/ranlib are the chain-built cctools ar/ranlib (cctools-ar, gcc-15);
        ## prepend so the chain ar resolves first. ARFLAGS=rcS keeps ar from
        ## auto-exec'ing ranlib (Make runs $(RANLIB) separately); the chain ar
        ## is downstream of gcc-15 so it can't replace host ar in the gcc chain.
        export PATH="${cctools-ar}/bin:${compiler}/bin:${cctools}/bin:$PATH"
        export CC="${compiler}/bin/gcc"
        export CXX="${compiler}/bin/g++"
        export AR="${cctools-ar}/bin/ar"
        export RANLIB="${cctools-ar}/bin/ranlib"
        export GCC_MODERN_WRAPPER_HOST_SHORTCUTS=0
        export GCC_MODERN_CONFTEST_TIMEOUT=120
        export CFLAGS="-O2 -g0"
        export CXXFLAGS="-O2 -g0"

        if ! ../hello-${gnuHelloVersion}/configure --disable-nls --prefix="$out" \
          > configure.stdout 2> configure.stderr; then
          tail -n 200 configure.stdout configure.stderr >&2
          exit 1
        fi
        ## chain-built make (bootstrap-gnumake, from tcc) builds GNU Hello's
        ## Automake recipe graph cleanly, including parallel -j (GNU Make 4.4.1).
        if ! ${bootstrap-gnumake}/bin/make -j"''${NIX_BUILD_CORES:-1}" ARFLAGS=rcS \
          > make.stdout 2> make.stderr; then
          tail -n 200 make.stdout make.stderr >&2
          exit 1
        fi

        ./hello > hello.stdout
        ./hello --version > version.stdout
        ./hello --help > help.stdout
        grep -qx 'Hello, world!' hello.stdout
        grep -q 'GNU Hello' version.stdout
        grep -q 'Usage:' help.stdout

        mkdir -p "$out/bin" "$out/share/darwin-bootstrap"
        cp ./hello "$out/bin/hello"
        cp configure.stdout configure.stderr \
          hello.stdout version.stdout help.stdout \
          "$out/share/darwin-bootstrap/"
        sha256sum "$out/bin/hello" | tee "$out/share/darwin-bootstrap/hello.sha256"
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

        export PATH="${gcc_latest}/bin:${gnumake}/bin:${cctools}/bin:$PATH"
        export CC="${gcc_latest}/bin/gcc"
        export CXX="${gcc_latest}/bin/g++"
        export NIX_HARDENING_ENABLE=
        export CFLAGS="-O2 -g0 -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=0"
        export CXXFLAGS="-O2 -g0 -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=0"

        if ! ../hello-${gnuHelloVersion}/configure --disable-nls --prefix="$out" \
          > configure.stdout 2> configure.stderr; then
          tail -n 200 configure.stdout configure.stderr >&2
          exit 1
        fi
        if ! ${gnumake}/bin/make -j"''${NIX_BUILD_CORES:-1}" ARFLAGS=rc \
          > make.stdout 2> make.stderr; then
          tail -n 200 make.stdout make.stderr >&2
          exit 1
        fi

        ./hello > hello.stdout
        ./hello --version > version.stdout
        ./hello --help > help.stdout
        grep -qx 'Hello, world!' hello.stdout
        grep -q 'GNU Hello' version.stdout
        grep -q 'Usage:' help.stdout

        mkdir -p "$out/bin" "$out/share/darwin-bootstrap"
        cp ./hello "$out/bin/hello"
        cp configure.stdout configure.stderr \
          hello.stdout version.stdout help.stdout \
          "$out/share/darwin-bootstrap/"
        {
          printf 'nixpkgs_gcc_latest_version='
          ${gcc_latest}/bin/gcc -dumpversion
        } > "$out/share/darwin-bootstrap/compiler.txt"
        sha256sum "$out/bin/hello" | tee "$out/share/darwin-bootstrap/hello.sha256"
      ''
    else
      null;

  gnu-hello-hash-comparison =
    if hostPlatform.isx86_64 then
      runCommand "darwin-minimal-bootstrap-gnu-hello-hash-comparison" { } ''
        ## Reproducibility gate. The bootstrap chain (gcc-latest) and the strict
        ## no-host-clang re-bootstrap (gcc-latest-strict) must produce the SAME
        ## GNU Hello, and that hash must equal the pinned bootstrap baseline.
        ## The nixpkgs reference is built through nixpkgs's compiler/linker
        ## wrappers, which deliberately add policy flags and RPATHs that the
        ## bootstrap wrapper does not.  It therefore has its own pinned baseline:
        ## requiring the two policy-distinct binaries to be byte-identical would
        ## test wrapper policy, not compiler self-hosting.  This derivation fails
        ## the build (and `nix flake check`) on drift in either baseline.
        expected_bootstrap=0854f4ab9cf255a37ddfb6251198164e6f14f3606239c963d2530f77e257f90a
        expected_nixpkgs=f23f901be1f6c913487bfc939364f746127357805c0ccbe2a922c7c6b793f417
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
          printf 'bootstrap_baseline_match=%s\n' "$([ "$phase47_hash" = "$expected_bootstrap" ] && echo yes || echo no)"
          printf 'nixpkgs_baseline_match=%s\n' "$([ "$nixpkgs_hash" = "$expected_nixpkgs" ] && echo yes || echo no)"
          cat ${gnu-hello-nixpkgs-gcc-latest}/share/darwin-bootstrap/compiler.txt
        } > "$out/share/darwin-bootstrap/hello-hashes.txt"
        cat "$out/share/darwin-bootstrap/hello-hashes.txt"

        fail=0
        if [ "$phase46_hash" != "$phase47_hash" ]; then
          echo "GATE FAIL: phase46 ($phase46_hash) != phase47 strict ($phase47_hash)" >&2
          fail=1
        fi
        if [ "$phase47_hash" != "$expected_bootstrap" ]; then
          echo "GATE FAIL: bootstrap hello hash ($phase47_hash) != pinned baseline ($expected_bootstrap)" >&2
          echo "  If the chain inputs changed intentionally, update 'expected_bootstrap' in gnu-hello.nix." >&2
          fail=1
        fi
        if [ "$nixpkgs_hash" != "$expected_nixpkgs" ]; then
          echo "GATE FAIL: nixpkgs reference hash ($nixpkgs_hash) != pinned baseline ($expected_nixpkgs)" >&2
          echo "  If the nixpkgs compiler-wrapper policy changed intentionally, update 'expected_nixpkgs' in gnu-hello.nix." >&2
          fail=1
        fi
        [ "$fail" = 0 ] || exit 1
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
