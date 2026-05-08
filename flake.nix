{
  description = "Darwin minimal bootstrap experiments for a stage0/M2-Planet/TCC path";

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
