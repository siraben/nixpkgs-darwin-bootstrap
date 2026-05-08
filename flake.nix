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
          default = bootstrap.raw-syscall-hello;
          hex0 = bootstrap.hex0;
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
