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
      ## `bootstrapFor` returns the full package set, keyed by semantic
      ## kebab names (hex1, kaem, gcc46, bootstrap-gnumake, ...) plus a few
      ## extras (hex0, raw-syscall-hello, etc).  We splat that wholesale and
      ## then layer on:
      ##   - `default` (chain-tip selector)
      ##   - semantic per-directory keys (e.g. "stage0-posix/hex1")
      packages = forAllSystems (
        system:
        let
          b = bootstrapFor system;
          semantic = nixpkgs.lib.optionalAttrs (b.hex1 != null) {
            "stage0-posix/hex1"             = b.hex1;
            "stage0-posix/hex2"             = b.hex2-0;
            "stage0-posix/catm"             = b.catm;
            "stage0-posix/m0"               = b.m0;
            "stage0-posix/cc-arch"          = b.cc-arch;
            "stage0-posix/m2-planet"        = b.m2;
            "stage0-posix/blood-elf-macho"  = b.blood-macho-0;
            "stage0-posix/M1-0"             = b.m1-0;
            "stage0-posix/hex2-1"           = b.hex2-1;
            "stage0-posix/M1"               = b.m1;
            "stage0-posix/hex2-linker"      = b.hex2;
            "stage0-posix/kaem"             = b.kaem;

            "mescc-tools/macho-patcher-early" = b.macho-patcher-early;
            "mescc-tools/macho-patcher"       = b.macho-patcher;
            "mescc-tools/elf64-to-m1"         = b.elf64-to-m1;
            "mescc-tools/m1-to-hex2"          = b.m1-to-hex2;
            "mescc-tools/hex2-data-relocs"    = b.hex2-data-relocs;
            "mescc-tools/cc-arch-helper"      = b.cc-arch-helper;

            "mes/m2-planet"   = b.m2-planet;
            "mes/source"      = b.mes-source;
            "mes/m2-compile"  = b.mes-m2-probe;
            "mes/m2-link"     = b.mes-macho-link-probe;
            "mes/m2"          = b.mes-m2;

            "mescc-libc/mescc-macho"     = b.mescc-macho-probe;
            "mescc-libc/libc-mini"       = b.mescc-libc-mini-probe;
            "mescc-libc/tinycc-mescc-m1" = b.tinycc-mescc-m1-probe;
            "mescc-libc/libmescc"        = b.mescc-libmescc-probe;
            "mescc-libc/libc"            = b.mescc-libc-probe;
            "mescc-libc/libc-tcc"        = b.mescc-libc-tcc-probe;

            "tinycc/mescc-link"   = b.tinycc-mescc-link-probe;
            "tinycc/compile"      = b.tinycc-compile-probe;
            "tinycc/self-object"  = b.tinycc-self-object-probe;
            "tinycc/elf-to-macho" = b.tinycc-elf-to-macho-probe;
            "tinycc/self-m1"      = b.tinycc-self-m1-probe;
            "tinycc/sysv-libc"    = b.tinycc-sysv-libc-probe;
            "tinycc/self-link"    = b.tinycc-self-link-candidate;
            "tinycc/self-compile" = b.tinycc-self-compile-probe;
            "tinycc/boot1-object" = b.tinycc-boot1-object-probe;
            "tinycc/boot1-link"   = b.tinycc-boot1-link-candidate;
            "tinycc/darwin-cc"    = b.tinycc-darwin-cc;
            "tinycc/boot2-object" = b.tinycc-boot2-object-probe;
            "tinycc/boot2-link"   = b.tinycc-boot2-link-candidate;
            "tinycc/boot3-object" = b.tinycc-boot3-object-probe;
            "tinycc/boot3-link"   = b.tinycc-boot3-link-candidate;

            "bootstrap-deps/gmp"  = b.bootstrap-gmp;
            "bootstrap-deps/mpfr" = b.bootstrap-mpfr;
            "bootstrap-deps/mpc"  = b.bootstrap-mpc;
            "bootstrap-deps/isl"  = b.bootstrap-isl;

            "gnumake"   = b.bootstrap-gnumake;
            "gnupatch"  = b.gnupatch;
            "coreutils" = b.coreutils-boot;

            "gcc-4.6/source"               = b.gcc46-source;
            "gcc-4.6/darwin-bootstrap-src" = b.gcc46DarwinBootstrapSrc;
            "gcc-4.6/all-gcc"              = b.gcc46-all-gcc;
            "gcc-4.6/libgcc"               = b.gcc46-libgcc;
            "gcc-4.6/bootstrap"            = b.gcc46;
            "gcc-4.6/cxx"                  = b.gcc46-cxx;

            "gcc-10/source"    = b.gcc10-source;
            "gcc-10/bootstrap" = b.gcc10;

            "gcc-latest/source"    = b.gcc-latest-source;
            "gcc-latest/bootstrap" = b.gcc-latest;
            "gcc-latest/strict"    = b.gcc-latest-strict;
          };
        in
        ## Base keys come from `b`; semantic + canonical names override.
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
            if b.gcc-latest-strict != null then
              b.gcc-latest-strict
            else if b.gcc46 != null then
              b.gcc46
            else
              b.raw-syscall-hello;

          gcc46-bootstrap            = b.gcc46;
          gcc10-bootstrap            = b.gcc10;
          gcc-latest-bootstrap       = b.gcc-latest-strict;
          gcc-latest-bootstrap-fast  = b.gcc-latest;

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
