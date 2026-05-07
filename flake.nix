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
