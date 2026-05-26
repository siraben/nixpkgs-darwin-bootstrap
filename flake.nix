{
  description = "Darwin minimal bootstrap experiments for a stage0/M2-Planet/Mes/TCC path";

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
      bootstrapFor = system:
        let
          pkgs = pkgsFor system;
        in
        pkgs.callPackage ./packages.nix { };
    in
    {
      packages = forAllSystems (
        system:
        let
          bootstrap = bootstrapFor system;
        in
        {
          default =
            if bootstrap.phase47-gcc-latest-strict-bootstrap != null then
              bootstrap.phase47-gcc-latest-strict-bootstrap
            else if bootstrap.phase37-gcc46-bootstrap != null then
              bootstrap.phase37-gcc46-bootstrap
            else
              bootstrap.raw-syscall-hello;
          hex0 = bootstrap.hex0;
          gcc46-bootstrap = bootstrap.phase37-gcc46-bootstrap;
          m2libc-darwin = bootstrap.m2libc-darwin;
          raw-syscall-hello = bootstrap.raw-syscall-hello;
          raw-syscall-hello-unsigned = bootstrap.raw-syscall-hello-unsigned;
        }
        // nixpkgs.lib.optionalAttrs (bootstrap.phase1-hex1 != null) {
          phase1-hex1 = bootstrap.phase1-hex1;
        }
        // nixpkgs.lib.optionalAttrs (bootstrap.phase2-hex2 != null) {
          phase2-hex2 = bootstrap.phase2-hex2;
          phase2-catm = bootstrap.phase2-catm;
        }
        // nixpkgs.lib.optionalAttrs (bootstrap.phase3-m0 != null) {
          phase3-m0 = bootstrap.phase3-m0;
          phase4-cc-arch = bootstrap.phase4-cc-arch;
          phase5-m2 = bootstrap.phase5-m2;
          phase6-blood-macho-0 = bootstrap.phase6-blood-macho-0;
          phase7-m1-0 = bootstrap.phase7-m1-0;
          phase8-hex2-1 = bootstrap.phase8-hex2-1;
          phase9-m1 = bootstrap.phase9-m1;
          phase10-hex2 = bootstrap.phase10-hex2;
          phase11-kaem = bootstrap.phase11-kaem;
          phase12-m2-planet = bootstrap.phase12-m2-planet;
          phase13-mes-source = bootstrap.phase13-mes-source;
          phase14-mes-m2-probe = bootstrap.phase14-mes-m2-probe;
          phase15-mes-macho-link-probe = bootstrap.phase15-mes-macho-link-probe;
          phase16-mes-m2 = bootstrap.phase16-mes-m2;
          phase17-mescc-macho-probe = bootstrap.phase17-mescc-macho-probe;
          phase18-mescc-libc-mini-probe = bootstrap.phase18-mescc-libc-mini-probe;
          phase19-tinycc-mescc-m1-probe = bootstrap.phase19-tinycc-mescc-m1-probe;
          phase20-mescc-libmescc-probe = bootstrap.phase20-mescc-libmescc-probe;
          phase21-mescc-libc-probe = bootstrap.phase21-mescc-libc-probe;
          phase22-mescc-libc-tcc-probe = bootstrap.phase22-mescc-libc-tcc-probe;
          phase23-tinycc-mescc-link-probe = bootstrap.phase23-tinycc-mescc-link-probe;
          phase24-tinycc-compile-probe = bootstrap.phase24-tinycc-compile-probe;
          phase25-tinycc-self-object-probe = bootstrap.phase25-tinycc-self-object-probe;
          phase26-gcc46-source = bootstrap.phase26-gcc46-source;
          phase26b-elf64-to-m1 = bootstrap.phase26b-elf64-to-m1;
          phase26c-bootstrap-gmp = bootstrap.phase26c-bootstrap-gmp;
          phase26d-bootstrap-mpfr = bootstrap.phase26d-bootstrap-mpfr;
          phase26e-bootstrap-mpc = bootstrap.phase26e-bootstrap-mpc;
          phase26f-bootstrap-isl = bootstrap.phase26f-bootstrap-isl;
          phase26g-macho-patcher = bootstrap.phase26g-macho-patcher;
          phase42-gcc10-source = bootstrap.phase42-gcc10-source;
          phase43-gcc-latest-source = bootstrap.phase43-gcc-latest-source;
          gcc46-darwin-bootstrap-src = bootstrap.gcc46DarwinBootstrapSrc;
          phase35-gcc46-all-gcc = bootstrap.phase35-gcc46-all-gcc;
          phase36-gcc46-libgcc = bootstrap.phase36-gcc46-libgcc;
          phase37-gcc46-bootstrap = bootstrap.phase37-gcc46-bootstrap;
          phase27-tinycc-elf-to-macho-probe = bootstrap.phase27-tinycc-elf-to-macho-probe;
          phase28-tinycc-self-m1-probe = bootstrap.phase28-tinycc-self-m1-probe;
          phase29-tinycc-sysv-libc-probe = bootstrap.phase29-tinycc-sysv-libc-probe;
          phase30-tinycc-self-link-candidate = bootstrap.phase30-tinycc-self-link-candidate;
          phase31-tinycc-self-compile-probe = bootstrap.phase31-tinycc-self-compile-probe;
          phase32-tinycc-boot1-object-probe = bootstrap.phase32-tinycc-boot1-object-probe;
          phase33-tinycc-boot1-link-candidate = bootstrap.phase33-tinycc-boot1-link-candidate;
          phase34-tinycc-darwin-cc = bootstrap.phase34-tinycc-darwin-cc;
          phase35-tinycc-boot2-object-probe = bootstrap.phase35-tinycc-boot2-object-probe;
          phase36-tinycc-boot2-link-candidate = bootstrap.phase36-tinycc-boot2-link-candidate;
          phase37-tinycc-boot3-object-probe = bootstrap.phase37-tinycc-boot3-object-probe;
          phase38-tinycc-boot3-link-candidate = bootstrap.phase38-tinycc-boot3-link-candidate;
          phase39-gnumake = bootstrap.phase39-gnumake;
          phase40-gnupatch = bootstrap.phase40-gnupatch;
          phase41-coreutils = bootstrap.phase41-coreutils;
          phase44-gcc46-cxx-bootstrap = bootstrap.phase44-gcc46-cxx-bootstrap;
          phase45-gcc10-bootstrap = bootstrap.phase45-gcc10-bootstrap;
          phase46-gcc-latest-bootstrap = bootstrap.phase46-gcc-latest-bootstrap;
          phase47-gcc-latest-strict-bootstrap = bootstrap.phase47-gcc-latest-strict-bootstrap;
          gcc10-bootstrap = bootstrap.phase45-gcc10-bootstrap;
          gcc-latest-bootstrap = bootstrap.phase47-gcc-latest-strict-bootstrap;
          gcc-latest-bootstrap-fast = bootstrap.phase46-gcc-latest-bootstrap;
          gnu-hello-gcc-latest-bootstrap = bootstrap.gnu-hello-gcc-latest-bootstrap;
          gnu-hello-gcc-latest-strict = bootstrap.gnu-hello-gcc-latest-strict;
          gnu-hello-nixpkgs-gcc-latest = bootstrap.gnu-hello-nixpkgs-gcc-latest;
          gnu-hello-hash-comparison = bootstrap.gnu-hello-hash-comparison;
          tinycc-m2-negative-probe = bootstrap.tinycc-m2-negative-probe;
          tinycc-bootstrappable-src = bootstrap.tinyccBootstrappableSrc;
          tinycc-mes-src = bootstrap.tinyccMesSrc;
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
