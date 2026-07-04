{ nixpkgs ? <nixpkgs>, system ? builtins.currentSystem }:

let
  chainSystem = if system == "aarch64-darwin" then "x86_64-darwin" else system;
  pkgs = import nixpkgs { system = chainSystem; };
in
pkgs.callPackage ./nix/packages.nix { }
