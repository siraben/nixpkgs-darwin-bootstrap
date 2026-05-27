{
  description = "Darwin minimal bootstrap (stage0-posix → mes → TinyCC → GCC), nixpkgs-style";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "aarch64-darwin"
        "x86_64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      pkgsFor = system: import nixpkgs { inherit system; };
      bootstrapFor =
        system:
        let
          pkgs = pkgsFor system;
        in
        pkgs.callPackage ./packages.nix { };
    in
    {
      ## --- Top-level flake outputs --------------------------------------
      ##
      ## `bootstrapFor` returns the full package set, keyed by both the
      ## legacy `phaseN-*` names and a few extras (hex0, raw-syscall-hello,
      ## etc).  We splat that wholesale and then layer on:
      ##   - `default` (chain-tip selector)
      ##   - semantic per-directory keys (e.g. "stage0-posix/hex1")
      ##   - a few short pname aliases (gcc46-bootstrap, ...)
      packages = forAllSystems (
        system:
        let
          b = bootstrapFor system;
          semantic = nixpkgs.lib.optionalAttrs (b.phase1-hex1 != null) {
            "stage0-posix/hex1"             = b.phase1-hex1;
            "stage0-posix/hex2"             = b.phase2-hex2;
            "stage0-posix/catm"             = b.phase2-catm;
            "stage0-posix/m0"               = b.phase3-m0;
            "stage0-posix/cc-arch"          = b.phase4-cc-arch;
            "stage0-posix/m2-planet"        = b.phase5-m2;
            "stage0-posix/blood-elf-macho"  = b.phase6-blood-macho-0;
            "stage0-posix/M1-0"             = b.phase7-m1-0;
            "stage0-posix/hex2-1"           = b.phase8-hex2-1;
            "stage0-posix/M1"               = b.phase9-m1;
            "stage0-posix/hex2-linker"      = b.phase10-hex2;
            "stage0-posix/kaem"             = b.phase11-kaem;

            "mescc-tools/macho-patcher-early" = b.phase11e-macho-patcher-early;
            "mescc-tools/macho-patcher"       = b.phase26g-macho-patcher;
            "mescc-tools/elf64-to-m1"         = b.phase26b-elf64-to-m1;
            "mescc-tools/m1-to-hex2"          = b.phase11b-m1-to-hex2;
            "mescc-tools/hex2-data-relocs"    = b.phase11c-hex2-data-relocs;
            "mescc-tools/cc-arch-helper"      = b.phase11d-cc-arch-helper;

            "mes/m2-planet"   = b.phase12-m2-planet;
            "mes/source"      = b.phase13-mes-source;
            "mes/m2-compile"  = b.phase14-mes-m2-probe;
            "mes/m2-link"     = b.phase15-mes-macho-link-probe;
            "mes/m2"          = b.phase16-mes-m2;

            "mescc-libc/mescc-macho"     = b.phase17-mescc-macho-probe;
            "mescc-libc/libc-mini"       = b.phase18-mescc-libc-mini-probe;
            "mescc-libc/tinycc-mescc-m1" = b.phase19-tinycc-mescc-m1-probe;
            "mescc-libc/libmescc"        = b.phase20-mescc-libmescc-probe;
            "mescc-libc/libc"            = b.phase21-mescc-libc-probe;
            "mescc-libc/libc-tcc"        = b.phase22-mescc-libc-tcc-probe;

            "tinycc/mescc-link"   = b.phase23-tinycc-mescc-link-probe;
            "tinycc/compile"      = b.phase24-tinycc-compile-probe;
            "tinycc/self-object"  = b.phase25-tinycc-self-object-probe;
            "tinycc/elf-to-macho" = b.phase27-tinycc-elf-to-macho-probe;
            "tinycc/self-m1"      = b.phase28-tinycc-self-m1-probe;
            "tinycc/sysv-libc"    = b.phase29-tinycc-sysv-libc-probe;
            "tinycc/self-link"    = b.phase30-tinycc-self-link-candidate;
            "tinycc/self-compile" = b.phase31-tinycc-self-compile-probe;
            "tinycc/boot1-object" = b.phase32-tinycc-boot1-object-probe;
            "tinycc/boot1-link"   = b.phase33-tinycc-boot1-link-candidate;
            "tinycc/darwin-cc"    = b.phase34-tinycc-darwin-cc;
            "tinycc/boot2-object" = b.phase35-tinycc-boot2-object-probe;
            "tinycc/boot2-link"   = b.phase36-tinycc-boot2-link-candidate;
            "tinycc/boot3-object" = b.phase37-tinycc-boot3-object-probe;
            "tinycc/boot3-link"   = b.phase38-tinycc-boot3-link-candidate;

            "bootstrap-deps/gmp"  = b.phase26c-bootstrap-gmp;
            "bootstrap-deps/mpfr" = b.phase26d-bootstrap-mpfr;
            "bootstrap-deps/mpc"  = b.phase26e-bootstrap-mpc;
            "bootstrap-deps/isl"  = b.phase26f-bootstrap-isl;

            "gnumake"   = b.phase39-gnumake;
            "gnupatch"  = b.phase40-gnupatch;
            "coreutils" = b.phase41-coreutils;

            "gcc-4.6/source"               = b.phase26-gcc46-source;
            "gcc-4.6/darwin-bootstrap-src" = b.gcc46DarwinBootstrapSrc;
            "gcc-4.6/all-gcc"              = b.phase35-gcc46-all-gcc;
            "gcc-4.6/libgcc"               = b.phase36-gcc46-libgcc;
            "gcc-4.6/bootstrap"            = b.phase37-gcc46-bootstrap;
            "gcc-4.6/cxx"                  = b.phase44-gcc46-cxx-bootstrap;

            "gcc-10/source"    = b.phase42-gcc10-source;
            "gcc-10/bootstrap" = b.phase45-gcc10-bootstrap;

            "gcc-latest/source"    = b.phase43-gcc-latest-source;
            "gcc-latest/bootstrap" = b.phase46-gcc-latest-bootstrap;
            "gcc-latest/strict"    = b.phase47-gcc-latest-strict-bootstrap;
          };
        in
        ## Phase-N-* keys come from `b`; semantic + canonical names override.
        ## Drop helpers and camelCase intermediates that have kebab aliases.
        removeAttrs b [
          "callPhase"
          "tests"
          "supportedSystems"
          "gcc46DarwinBootstrapSrc"
          "tinyccBootstrappableSrc"
          "tinyccMesSrc"
          "tinyccSelfObjectProbe"
          "tinyccSelfLinkCandidate"
        ] // semantic // {
          default =
            if b.phase47-gcc-latest-strict-bootstrap != null then
              b.phase47-gcc-latest-strict-bootstrap
            else if b.phase37-gcc46-bootstrap != null then
              b.phase37-gcc46-bootstrap
            else
              b.raw-syscall-hello;

          gcc46-bootstrap            = b.phase37-gcc46-bootstrap;
          gcc10-bootstrap            = b.phase45-gcc10-bootstrap;
          gcc-latest-bootstrap       = b.phase47-gcc-latest-strict-bootstrap;
          gcc-latest-bootstrap-fast  = b.phase46-gcc-latest-bootstrap;

          gcc46-darwin-bootstrap-src = b.gcc46DarwinBootstrapSrc;
          tinycc-bootstrappable-src  = b.tinyccBootstrappableSrc;
          tinycc-mes-src             = b.tinyccMesSrc;
        }
      );

      checks = forAllSystems (system: (bootstrapFor system).tests);

      devShells = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
        in
        {
          default = pkgs.mkShell {
            packages = [
              pkgs.cctools
              pkgs.darwin.sigtool
            ];
          };
        }
      );
    };
}
