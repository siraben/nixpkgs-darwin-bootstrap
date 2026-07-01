{ nixpkgs ? <nixpkgs>, system ? builtins.currentSystem }:

let
  pkgs = import nixpkgs { inherit system; };
in
pkgs.callPackage ./nix/packages.nix { }
